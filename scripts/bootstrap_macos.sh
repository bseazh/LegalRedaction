#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "当前完整语义模型使用 MLX，仅支持 Apple Silicon。Intel Mac 请使用规则模式。" >&2
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "未检测到 Homebrew。请先安装：https://brew.sh/" >&2
  exit 1
fi

brew install python@3.13 node poppler rustup-init
if ! command -v rustc >/dev/null 2>&1; then
  rustup-init -y
fi

python3.13 -m venv .venv-mlx
source .venv-mlx/bin/activate
python -m pip install --upgrade pip
python -m pip install -r service/requirements-macos.txt
npm --prefix app ci

if [[ "$(uname -m)" == "arm64" ]]; then
  python scripts/download_model.py
fi

echo "安装完成。运行：./scripts/start_macos.sh"
