from __future__ import annotations

import argparse
import json
from pathlib import Path

from .redaction_core import scan_file


def main() -> int:
    parser = argparse.ArgumentParser(description="P0 local legal redaction prototype")
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, help="write JSON results to this path")
    parser.add_argument("--include-text", action="store_true", help="include redacted text; off by default")
    args = parser.parse_args()

    results = []
    for path in args.paths:
        try:
            result = scan_file(path)
            if not args.include_text:
                result.pop("redacted_text", None)
            results.append({"ok": True, **result})
        except Exception as exc:  # CLI should report one bad file without losing the batch.
            results.append({"ok": False, "file": str(path), "error": str(exc)})
    payload = json.dumps(results, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    else:
        print(payload)
    return 0 if all(item["ok"] for item in results) else 2


if __name__ == "__main__":
    raise SystemExit(main())

