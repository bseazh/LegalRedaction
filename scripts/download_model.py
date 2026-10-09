from __future__ import annotations

import argparse
from pathlib import Path

from huggingface_hub import snapshot_download


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description="Download PrivacyGuard model weights from Hugging Face")
    parser.add_argument("--repo", default="mlx-community/Qwen3-1.7B-bf16")
    parser.add_argument("--output", type=Path, default=ROOT / "models/qwen3/Qwen3-1.7B-bf16")
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    snapshot_download(repo_id=args.repo, local_dir=args.output)
    print(f"Model ready: {args.output.resolve()}")


if __name__ == "__main__":
    main()
