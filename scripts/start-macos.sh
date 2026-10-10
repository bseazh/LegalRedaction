#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
MAC_ARCH="$(uname -m)"

APP_PYTHON="$BACKEND_DIR/.venv-mac/bin/python"
OCR_PYTHON="$BACKEND_DIR/.venv-ocr-mac/bin/python"
LOCATE_PYTHON="$BACKEND_DIR/.venv-locate-mac/bin/python"
LOCATE_MODEL="$BACKEND_DIR/models/locateanything/LocateAnything-3B-HF"

require_executable() {
  if [[ ! -x "$1" ]]; then
    print -u2 "缺少运行环境：$1"
    print -u2 "请先安装对应的 macOS Python 依赖。"
    exit 1
  fi
}

remove_job() {
  launchctl remove "$1" >/dev/null 2>&1 || true
}

submit_job() {
  local label="$1"
  local stdout_path="$2"
  local stderr_path="$3"
  shift 3
  remove_job "$label"
  sleep 1
  launchctl submit -l "$label" -o "$stdout_path" -e "$stderr_path" -- "$@"
}

require_executable "$APP_PYTHON"
require_executable "$OCR_PYTHON"

MPS_AVAILABLE="false"
if [[ -x "$LOCATE_PYTHON" ]]; then
  MPS_AVAILABLE="$($LOCATE_PYTHON -c 'import torch; print("true" if torch.backends.mps.is_available() else "false")' 2>/dev/null || print false)"
fi

DETECTED_DEVICE="cpu"
if [[ "$MPS_AVAILABLE" == "true" ]]; then
  DETECTED_DEVICE="mps"
fi

LOCATE_DEVICE="${LOCATE_ANYTHING_DEVICE:-$DETECTED_DEVICE}"
LOCATE_DTYPE="${LOCATE_ANYTHING_DTYPE:-$([[ "$LOCATE_DEVICE" == "mps" ]] && print float16 || print float32)}"
LOCATE_MAX_SIDE="${LOCATE_ANYTHING_MAX_IMAGE_SIDE:-640}"
LOCATE_MAX_TOKENS="${LOCATE_ANYTHING_MAX_NEW_TOKENS:-256}"
ALLOW_LOCATE_CPU="${LOCATE_ANYTHING_ALLOW_CPU:-0}"
START_VISUAL="true"

if [[ ! -x "$LOCATE_PYTHON" || ! -f "$LOCATE_MODEL/model.safetensors.index.json" ]]; then
  START_VISUAL="false"
  print -u2 "视觉模型环境或权重不存在，将启动 OCR + HaS，视觉服务保持离线。"
elif [[ "$LOCATE_DEVICE" == "cpu" && "$ALLOW_LOCATE_CPU" != "1" ]]; then
  START_VISUAL="false"
  print -u2 "当前 Mac 没有可用的 PyTorch MPS；LocateAnything-3B CPU 模式默认禁用。"
  print -u2 "如需强制尝试，请设置 LOCATE_ANYTHING_ALLOW_CPU=1。"
fi

print "macOS 架构：$MAC_ARCH"
print "PyTorch MPS：$MPS_AVAILABLE"
print "OCR：Paddle CPU 兼容模式"
print "HaS：llama.cpp / Metal（不可用时由 llama.cpp 自身回退）"
print "视觉模型：$([[ "$START_VISUAL" == "true" ]] && print "$LOCATE_DEVICE / $LOCATE_DTYPE" || print disabled)"

remove_job com.bigapple.redaction.locatemps

submit_job com.bigapple.redaction.has /tmp/redaction-has-mac.log /tmp/redaction-has-mac.err \
  /usr/bin/env \
  "HAS_MODEL_PATH=$BACKEND_DIR/models/has/has_4.0_0.6B.gguf" \
  HAS_TEXT_HOST=127.0.0.1 HAS_TEXT_PORT=8080 HAS_TEXT_N_CTX=4096 \
  "HAS_TEXT_N_GPU_LAYERS=${HAS_TEXT_N_GPU_LAYERS:--1}" \
  "$APP_PYTHON" "$BACKEND_DIR/scripts/start_has_python.py"

submit_job com.bigapple.redaction.ocr /tmp/redaction-ocr-mac.log /tmp/redaction-ocr-mac.err \
  /usr/bin/env \
  "OCR_DEVICE=${OCR_DEVICE:-cpu}" OCR_VL_ENABLED=0 OCR_STRUCTURE_ENABLED=1 OCR_STRUCTURE_WARMUP=0 \
  "PADDLE_PDX_CACHE_HOME=${PADDLE_PDX_CACHE_HOME:-$BACKEND_DIR/models/paddlex-cache}" \
  PADDLE_PDX_MODEL_SOURCE=modelscope PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True OCR_PORT=8082 \
  "$OCR_PYTHON" "$BACKEND_DIR/scripts/ocr_server.py"

if [[ "$START_VISUAL" == "true" ]]; then
  submit_job com.bigapple.redaction.locate /tmp/redaction-locate-mac.log /tmp/redaction-locate-mac.err \
    /usr/bin/env \
    PYTORCH_ENABLE_MPS_FALLBACK=1 "LOCATE_ANYTHING_DEVICE=$LOCATE_DEVICE" \
    "LOCATE_ANYTHING_MODEL=$LOCATE_MODEL" LOCATE_ANYTHING_BACKEND=hf \
    "LOCATE_ANYTHING_DTYPE=$LOCATE_DTYPE" \
    "LOCATE_ANYTHING_MAX_IMAGE_SIDE=$LOCATE_MAX_SIDE" \
    "LOCATE_ANYTHING_MIN_IMAGE_SIDE=$LOCATE_MAX_SIDE" \
    "LOCATE_ANYTHING_MAX_NEW_TOKENS=$LOCATE_MAX_TOKENS" LOCATE_ANYTHING_PORT=8090 \
    "$LOCATE_PYTHON" "$BACKEND_DIR/scripts/locate_anything_server.py"
else
  remove_job com.bigapple.redaction.locate
fi

submit_job com.bigapple.redaction.app /tmp/redaction-app-mac.log /tmp/redaction-app-mac.err \
  /usr/bin/env \
  AUTH_ENABLED=false DEBUG=false \
  "DATA_DIR=$BACKEND_DIR/data" "UPLOAD_DIR=$BACKEND_DIR/uploads" "OUTPUT_DIR=$BACKEND_DIR/outputs" \
  HAS_TEXT_RUNTIME=llamacpp HAS_LLAMACPP_BASE_URL=http://127.0.0.1:8080/v1 \
  HAS_NER_CONTEXT_TOKENS=4096 HAS_NER_MAX_TOKENS=1024 \
  OCR_BASE_URL=http://127.0.0.1:8082 OCR_REQUIRE_GPU=false \
  VISUAL_FEATURES_BASE_URL=http://127.0.0.1:8090 "LOCATE_ANYTHING_DEVICE=$LOCATE_DEVICE" \
  "$APP_PYTHON" -m uvicorn app.main:app \
  --app-dir "$BACKEND_DIR" --host 127.0.0.1 --port 8000

print "服务已提交。视觉模型首次加载通常需要 15–30 秒。"
print "应用：http://127.0.0.1:8000"
print "状态：http://127.0.0.1:8000/health/services"
