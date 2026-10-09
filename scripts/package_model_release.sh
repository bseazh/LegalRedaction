#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
model_dir="${1:-$project_dir/models/qwen3/Qwen3-1.7B-bf16}"
output_dir="${2:-$project_dir/model-release}"

if [[ ! -d "$model_dir" ]]; then
  echo "模型目录不存在：$model_dir" >&2
  exit 1
fi
mkdir -p "$output_dir"
archive="$output_dir/Qwen3-1.7B-bf16.tar.gz"
tar -C "${model_dir:h}" -czf "$archive" "${model_dir:t}"
split -b 1900m -d -a 2 "$archive" "$archive.part-"
shasum -a 256 "$archive".part-* > "$output_dir/SHA256SUMS"
rm "$archive"
echo "Release 分片已生成：$output_dir"
echo "上传示例：gh release upload MODEL_VERSION $output_dir/*.part-* $output_dir/SHA256SUMS"
