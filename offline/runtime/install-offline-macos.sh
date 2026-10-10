#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="${1:-$(cd "$ROOT_DIR/.." && pwd)}"
VERSION="$(cat "$ROOT_DIR/OFFLINE_VERSION")"
HAS_ARCHIVE="PrivacyGuard-standard-model-has-$VERSION.tar.gz"
OCR_ARCHIVE="PrivacyGuard-standard-model-paddleocr-$VERSION.tar.gz"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  print -u2 "此离线包仅支持 macOS Apple Silicon（arm64）。"
  exit 1
fi

verify_component() {
  local file="$1"
  local expected
  expected="$(awk -v name="$(basename "$file")" '$2 == name {print $1}' "$ROOT_DIR/COMPONENTS.sha256")"
  [[ -n "$expected" ]] || { print -u2 "校验清单中没有 $(basename "$file")"; exit 1; }
  local actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || { print -u2 "SHA-256 校验失败：$file"; exit 1; }
}

for archive in "$HAS_ARCHIVE" "$OCR_ARCHIVE"; do
  candidate="$PACKAGE_DIR/$archive"
  [[ -f "$candidate" ]] || candidate="$ROOT_DIR/packages/$archive"
  [[ -f "$candidate" ]] || { print -u2 "缺少模型包：$archive"; exit 1; }
  print "校验 $archive ..."
  verify_component "$candidate"
  tar -xzf "$candidate" -C "$ROOT_DIR"
done

PYTHON_BIN=""
for candidate in \
  /Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11 \
  /opt/homebrew/bin/python3.11 \
  "$(command -v python3.11 2>/dev/null || true)"
do
  if [[ -n "$candidate" && -x "$candidate" ]]; then PYTHON_BIN="$candidate"; break; fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  print -u2 "未找到 Python 3.11。请先双击安装："
  print -u2 "$ROOT_DIR/prerequisites/python-3.11.9-macos11.pkg"
  exit 1
fi

mkdir -p "$ROOT_DIR/backend/data" "$ROOT_DIR/backend/uploads" "$ROOT_DIR/backend/outputs" "$ROOT_DIR/logs"
rm -rf "$ROOT_DIR/backend/.venv-mac" "$ROOT_DIR/backend/.venv-ocr-mac"
"$PYTHON_BIN" -m venv "$ROOT_DIR/backend/.venv-mac"
"$PYTHON_BIN" -m venv "$ROOT_DIR/backend/.venv-ocr-mac"

"$ROOT_DIR/backend/.venv-mac/bin/python" -m pip install --no-index --find-links "$ROOT_DIR/wheelhouse/app" -r "$ROOT_DIR/offline/requirements/macos-app.txt"
"$ROOT_DIR/backend/.venv-ocr-mac/bin/python" -m pip install --no-index --find-links "$ROOT_DIR/wheelhouse/ocr" -r "$ROOT_DIR/offline/requirements/macos-ocr.txt"

"$ROOT_DIR/backend/.venv-mac/bin/python" -c 'import fastapi, fitz, llama_cpp, docx; print("应用环境正常")'
"$ROOT_DIR/backend/.venv-ocr-mac/bin/python" -c 'import paddle, paddleocr; print("OCR 环境正常")'

print "离线安装完成。"
print "启动：$ROOT_DIR/scripts/start-macos.sh"
print "停止：$ROOT_DIR/scripts/stop-macos.sh"
