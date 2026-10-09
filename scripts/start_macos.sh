#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"
source .venv-mlx/bin/activate

if [[ "$(uname -m)" != "arm64" ]]; then
  export PRIVACYGUARD_NER_BACKEND=rules
fi

python -m service.local_api &
api_pid=$!
trap 'kill "$api_pid" 2>/dev/null || true' EXIT INT TERM
npm --prefix app run dev
