#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${OFFLINE_VERSION:-v0.1.2}"
OUT_DIR="${OFFLINE_OUTPUT_DIR:-$ROOT_DIR/dist/offline/$VERSION}"
WORK_DIR="$(mktemp -d /private/tmp/privacyguard-offline.XXXXXX)"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3.11)}"
LLAMA_TAG="${LLAMA_CPP_TAG:-b11540}"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

RELEASE_TAG="offline-standard-$VERSION"
if [[ -d "$OUT_DIR" && -n "$(find "$OUT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  print -u2 "拒绝覆盖已有不可变版本目录：$OUT_DIR"
  print -u2 "请通过 OFFLINE_VERSION 指定一个尚未使用的新版本。"
  exit 2
fi
if git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  print -u2 "拒绝重建已有 Git tag：$RELEASE_TAG"
  exit 2
fi
if git -C "$ROOT_DIR" ls-remote --exit-code privacyguard "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  print -u2 "拒绝重建远端已有 Git tag：$RELEASE_TAG"
  exit 2
fi
if command -v gh >/dev/null 2>&1 && gh release view "$RELEASE_TAG" --repo bseazh/PrivacyGuard >/dev/null 2>&1; then
  print -u2 "拒绝重建已有 GitHub Release：$RELEASE_TAG"
  exit 2
fi
mkdir -p "$OUT_DIR"

HAS_NAME="PrivacyGuard-standard-model-has-$VERSION.tar.gz"
OCR_NAME="PrivacyGuard-standard-model-paddleocr-$VERSION.tar.gz"
MAC_NAME="PrivacyGuard-standard-macos-arm64-runtime-$VERSION.tar.gz"
WIN_NAME="PrivacyGuard-standard-windows-x64-runtime-$VERSION.zip"

[[ -f "$ROOT_DIR/backend/models/has/has_4.0_0.6B.gguf" ]] || { print -u2 "缺少 HaS GGUF"; exit 1; }
[[ -d "$HOME/.paddlex/official_models" ]] || { print -u2 "缺少 PaddleX OCR 模型缓存"; exit 1; }
[[ -d "$ROOT_DIR/frontend/dist" ]] || { print -u2 "缺少 frontend/dist，请先构建前端"; exit 1; }

print "[1/6] 构建共享模型包"
if [[ ! -f "$OUT_DIR/$HAS_NAME" ]]; then
  mkdir -p "$WORK_DIR/has/backend/models/has"
  cp "$ROOT_DIR/backend/models/has/has_4.0_0.6B.gguf" "$WORK_DIR/has/backend/models/has/"
  cp "$ROOT_DIR/offline/THIRD_PARTY_MODELS.md" "$WORK_DIR/has/"
  tar -czf "$OUT_DIR/$HAS_NAME" -C "$WORK_DIR/has" .
fi
if [[ ! -f "$OUT_DIR/$OCR_NAME" ]]; then
  mkdir -p "$WORK_DIR/ocr/backend/models/paddlex-cache"
  cp -R "$HOME/.paddlex/official_models" "$WORK_DIR/ocr/backend/models/paddlex-cache/"
  cp "$ROOT_DIR/offline/THIRD_PARTY_MODELS.md" "$WORK_DIR/ocr/"
  tar -czf "$OUT_DIR/$OCR_NAME" -C "$WORK_DIR/ocr" .
fi

print "[2/6] 下载 macOS 离线 wheel"
mkdir -p "$WORK_DIR/mac/wheelhouse/app" "$WORK_DIR/mac/wheelhouse/ocr"
grep -v '^llama-cpp-python' "$ROOT_DIR/offline/requirements/macos-app.txt" > "$WORK_DIR/macos-app-without-llama.txt"
"$PYTHON_BIN" -m pip download --only-binary=:all: --dest "$WORK_DIR/mac/wheelhouse/app" -r "$WORK_DIR/macos-app-without-llama.txt"
LLAMA_WHEEL="$(find "$HOME/Library/Caches/pip" -name 'llama_cpp_python-0.3.36-*-macosx_*_arm64.whl' -print -quit)"
[[ -n "$LLAMA_WHEEL" ]] || { print -u2 "未找到本机 llama-cpp-python arm64 wheel 缓存"; exit 1; }
cp "$LLAMA_WHEEL" "$WORK_DIR/mac/wheelhouse/app/"
"$PYTHON_BIN" -m pip download --only-binary=:all: --dest "$WORK_DIR/mac/wheelhouse/ocr" -r "$ROOT_DIR/offline/requirements/macos-ocr.txt"

print "[3/6] 下载 Windows x64 离线 wheel"
mkdir -p "$WORK_DIR/win/wheelhouse/app" "$WORK_DIR/win/wheelhouse/ocr"
COMMON_WIN=(--only-binary=:all: --platform win_amd64 --python-version 311 --implementation cp --abi cp311)
"$PYTHON_BIN" -m pip download "${COMMON_WIN[@]}" --dest "$WORK_DIR/win/wheelhouse/app" -r "$ROOT_DIR/offline/requirements/windows-app.txt"
"$PYTHON_BIN" -m pip download "${COMMON_WIN[@]}" --dest "$WORK_DIR/win/wheelhouse/ocr" -r "$ROOT_DIR/offline/requirements/windows-ocr.txt"

print "[4/6] 下载官方 Python 与 llama.cpp 运行时"
mkdir -p "$WORK_DIR/mac/prerequisites" "$WORK_DIR/win/prerequisites" "$WORK_DIR/win/runtime/llama"
curl -fL --retry 3 -o "$WORK_DIR/mac/prerequisites/python-3.11.9-macos11.pkg" https://www.python.org/ftp/python/3.11.9/python-3.11.9-macos11.pkg
curl -fL --retry 3 -o "$WORK_DIR/win/prerequisites/python-3.11.9-amd64.exe" https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
gh release download "$LLAMA_TAG" --repo ggml-org/llama.cpp --pattern "llama-$LLAMA_TAG-bin-win-cpu-x64.zip" --dir "$WORK_DIR"
ditto -xk "$WORK_DIR/llama-$LLAMA_TAG-bin-win-cpu-x64.zip" "$WORK_DIR/win/runtime/llama"

copy_application() {
  local target="$1"
  mkdir -p "$target/backend" "$target/frontend" "$target/scripts" "$target/docs/installation" "$target/offline/requirements"
  rsync -a --exclude '__pycache__' --exclude '*.pyc' "$ROOT_DIR/backend/app" "$target/backend/"
  rsync -a --exclude '__pycache__' --exclude '*.pyc' "$ROOT_DIR/backend/scripts" "$target/backend/"
  [[ -d "$ROOT_DIR/backend/config" ]] && rsync -a "$ROOT_DIR/backend/config" "$target/backend/"
  rsync -a "$ROOT_DIR/frontend/dist" "$target/frontend/"
  rsync -a "$ROOT_DIR/docs/installation/" "$target/docs/installation/"
  cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/CHANGELOG.md" "$ROOT_DIR/offline/THIRD_PARTY_MODELS.md" "$target/"
  cp "$ROOT_DIR/offline/requirements/"*.txt "$target/offline/requirements/"
  mkdir -p "$target/backend/data" "$target/backend/uploads" "$target/backend/outputs" "$target/backend/models"
  print "$VERSION" > "$target/OFFLINE_VERSION"
}

print "[5/6] 组装平台运行包"
copy_application "$WORK_DIR/mac"
copy_application "$WORK_DIR/win"
cp "$ROOT_DIR/scripts/start-macos.sh" "$ROOT_DIR/scripts/stop-macos.sh" "$ROOT_DIR/scripts/test-macos.sh" "$WORK_DIR/mac/scripts/"
cp "$ROOT_DIR/scripts/check-offline-macos.sh" "$WORK_DIR/mac/"
cp "$ROOT_DIR/offline/runtime/install-offline-macos.sh" "$WORK_DIR/mac/"
cp "$ROOT_DIR/offline/runtime/Install-PrivacyGuard.command" "$ROOT_DIR/offline/runtime/Launch-PrivacyGuard.command" "$ROOT_DIR/offline/runtime/Test-PrivacyGuard.command" "$ROOT_DIR/offline/runtime/Stop-PrivacyGuard.command" "$WORK_DIR/mac/"
cp "$ROOT_DIR/offline/runtime/OFFLINE-README.md" "$WORK_DIR/mac/README-OFFLINE.md"
cp "$ROOT_DIR/offline/runtime/Install-Offline-Windows.ps1" "$ROOT_DIR/offline/runtime/Start-PrivacyGuard.ps1" "$ROOT_DIR/offline/runtime/Test-PrivacyGuard.ps1" "$ROOT_DIR/offline/runtime/Stop-PrivacyGuard.ps1" "$WORK_DIR/win/"
cp "$ROOT_DIR/offline/runtime/Install-PrivacyGuard.cmd" "$ROOT_DIR/offline/runtime/Launch-PrivacyGuard.cmd" "$ROOT_DIR/offline/runtime/Check-PrivacyGuard.cmd" "$ROOT_DIR/offline/runtime/Stop-PrivacyGuard.cmd" "$WORK_DIR/win/"
cp "$ROOT_DIR/scripts/check-offline-windows.ps1" "$WORK_DIR/win/Check-Offline-Windows.ps1"
cp "$ROOT_DIR/offline/runtime/OFFLINE-README.md" "$WORK_DIR/win/README-OFFLINE.md"
chmod +x "$WORK_DIR/mac/check-offline-macos.sh" "$WORK_DIR/mac/install-offline-macos.sh" "$WORK_DIR/mac/"*.command "$WORK_DIR/mac/scripts/"*.sh

(cd "$OUT_DIR" && shasum -a 256 "$HAS_NAME" "$OCR_NAME") > "$WORK_DIR/components.sha256"
cp "$WORK_DIR/components.sha256" "$WORK_DIR/mac/COMPONENTS.sha256"
cp "$WORK_DIR/components.sha256" "$WORK_DIR/win/COMPONENTS.sha256"
tar -czf "$OUT_DIR/$MAC_NAME" -C "$WORK_DIR/mac" .
(cd "$WORK_DIR/win" && zip -qry "$OUT_DIR/$WIN_NAME" .)

print "[6/6] 生成发行校验文件"
(cd "$OUT_DIR" && shasum -a 256 "$HAS_NAME" "$OCR_NAME" "$MAC_NAME" "$WIN_NAME") > "$OUT_DIR/SHA256SUMS"
du -sh "$OUT_DIR"/*
print "离线包目录：$OUT_DIR"
