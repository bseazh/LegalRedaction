#!/bin/zsh
set -euo pipefail

NO_BROWSER="false"
[[ "${1:-}" == "--no-browser" ]] && NO_BROWSER="true"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
MAC_ARCH="$(uname -m)"

APP_PYTHON="$BACKEND_DIR/.venv-mac/bin/python"
OCR_PYTHON="$BACKEND_DIR/.venv-ocr-mac/bin/python"
LOCATE_PYTHON="$BACKEND_DIR/.venv-locate-mac/bin/python"
LOCATE_MODEL="$BACKEND_DIR/models/locateanything/LocateAnything-3B-HF"
RUN_DIR="$ROOT_DIR/.run"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$RUN_DIR" "$LOG_DIR"
START_COMPLETE="false"

cleanup_failed_start() {
  if [[ "$START_COMPLETE" != "true" ]]; then
    print -u2 "启动未完成，正在清理本次启动的 PrivacyGuard 服务；日志会继续保留。"
    for label in com.bigapple.redaction.app com.bigapple.redaction.has com.bigapple.redaction.ocr com.bigapple.redaction.locate com.bigapple.redaction.locatemps; do
      launchctl remove "$label" >/dev/null 2>&1 || true
    done
  fi
}
trap cleanup_failed_start EXIT

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

port_available() {
  ! lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

select_port() {
  local service="$1"
  shift
  local port
  for port in "$@"; do
    if port_available "$port"; then print "$port"; return 0; fi
  done
  print -u2 "$service 没有可用端口：$*"
  return 1
}

require_executable "$APP_PYTHON"
require_executable "$OCR_PYTHON"

# Restart only launchd jobs created by PrivacyGuard; never terminate unrelated port owners.
remove_job com.bigapple.redaction.app
remove_job com.bigapple.redaction.has
remove_job com.bigapple.redaction.ocr
remove_job com.bigapple.redaction.locate
remove_job com.bigapple.redaction.locatemps
sleep 1

APP_PORT="$(select_port 应用 8000 18000 28000 38000)"
HAS_PORT="$(select_port HaS 8080 18080 28080 38080)"
OCR_SELECTED_PORT="$(select_port OCR 8082 18082 28082 38082)"
LOCATE_PORT="$(select_port 视觉服务 8090 18090 28090 38090)"

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

submit_job com.bigapple.redaction.has /tmp/redaction-has-mac.log /tmp/redaction-has-mac.err \
  /usr/bin/env \
  "HAS_MODEL_PATH=$BACKEND_DIR/models/has/has_4.0_0.6B.gguf" \
  HAS_TEXT_HOST=127.0.0.1 "HAS_TEXT_PORT=$HAS_PORT" HAS_TEXT_N_CTX=4096 \
  "HAS_TEXT_N_GPU_LAYERS=${HAS_TEXT_N_GPU_LAYERS:--1}" \
  "$APP_PYTHON" "$BACKEND_DIR/scripts/start_has_python.py"

submit_job com.bigapple.redaction.ocr /tmp/redaction-ocr-mac.log /tmp/redaction-ocr-mac.err \
  /usr/bin/env \
  "OCR_DEVICE=${OCR_DEVICE:-cpu}" OCR_VL_ENABLED=0 OCR_STRUCTURE_ENABLED=1 OCR_STRUCTURE_WARMUP=0 \
  "PADDLE_PDX_CACHE_HOME=${PADDLE_PDX_CACHE_HOME:-$BACKEND_DIR/models/paddlex-cache}" \
  PADDLE_PDX_MODEL_SOURCE=modelscope PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True "OCR_PORT=$OCR_SELECTED_PORT" \
  "$OCR_PYTHON" "$BACKEND_DIR/scripts/ocr_server.py"

if [[ "$START_VISUAL" == "true" ]]; then
  submit_job com.bigapple.redaction.locate /tmp/redaction-locate-mac.log /tmp/redaction-locate-mac.err \
    /usr/bin/env \
    PYTORCH_ENABLE_MPS_FALLBACK=1 "LOCATE_ANYTHING_DEVICE=$LOCATE_DEVICE" \
    "LOCATE_ANYTHING_MODEL=$LOCATE_MODEL" LOCATE_ANYTHING_BACKEND=hf \
    "LOCATE_ANYTHING_DTYPE=$LOCATE_DTYPE" \
    "LOCATE_ANYTHING_MAX_IMAGE_SIDE=$LOCATE_MAX_SIDE" \
    "LOCATE_ANYTHING_MIN_IMAGE_SIDE=$LOCATE_MAX_SIDE" \
    "LOCATE_ANYTHING_MAX_NEW_TOKENS=$LOCATE_MAX_TOKENS" "LOCATE_ANYTHING_PORT=$LOCATE_PORT" \
    "$LOCATE_PYTHON" "$BACKEND_DIR/scripts/locate_anything_server.py"
else
  remove_job com.bigapple.redaction.locate
fi

submit_job com.bigapple.redaction.app /tmp/redaction-app-mac.log /tmp/redaction-app-mac.err \
  /usr/bin/env \
  AUTH_ENABLED=false DEBUG=false \
  "DATA_DIR=$BACKEND_DIR/data" "UPLOAD_DIR=$BACKEND_DIR/uploads" "OUTPUT_DIR=$BACKEND_DIR/outputs" \
  HAS_TEXT_RUNTIME=llamacpp "HAS_LLAMACPP_BASE_URL=http://127.0.0.1:$HAS_PORT/v1" \
  HAS_NER_CONTEXT_TOKENS=4096 HAS_NER_MAX_TOKENS=1024 \
  "OCR_BASE_URL=http://127.0.0.1:$OCR_SELECTED_PORT" OCR_REQUIRE_GPU=false \
  "VISUAL_FEATURES_BASE_URL=http://127.0.0.1:$LOCATE_PORT" "LOCATE_ANYTHING_DEVICE=$LOCATE_DEVICE" \
  "$APP_PYTHON" -m uvicorn app.main:app \
  --app-dir "$BACKEND_DIR" --host 127.0.0.1 --port "$APP_PORT"

cat > "$RUN_DIR/runtime.env" <<EOF
APP_URL=http://127.0.0.1:$APP_PORT
HEALTH_URL=http://127.0.0.1:$APP_PORT/health
SERVICES_URL=http://127.0.0.1:$APP_PORT/health/services
APP_PORT=$APP_PORT
HAS_PORT=$HAS_PORT
OCR_PORT=$OCR_SELECTED_PORT
LOCATE_PORT=$LOCATE_PORT
EOF

print "服务已提交，正在等待后端和模型服务（首次启动可能需要数分钟）..."
deadline=$((SECONDS + 300))
until curl -fsS --max-time 10 "http://127.0.0.1:$APP_PORT/health" >/dev/null 2>&1; do
  (( SECONDS < deadline )) || { print -u2 "后端启动超时，请运行 ./Test-PrivacyGuard.command；日志位于 /tmp/redaction-*-mac.*"; exit 1; }
  sleep 2
done

until "$ROOT_DIR/scripts/test-macos.sh" >/dev/null 2>&1; do
  (( SECONDS < deadline )) || { print -u2 "模型服务启动超时，请双击 Test-PrivacyGuard.command 查看状态。"; exit 1; }
  sleep 5
done
"$ROOT_DIR/scripts/test-macos.sh"
START_COMPLETE="true"
print "应用：http://127.0.0.1:$APP_PORT"
print "以后可直接双击 Launch-PrivacyGuard.command 启动。"
if [[ "$NO_BROWSER" != "true" ]]; then open "http://127.0.0.1:$APP_PORT"; fi
