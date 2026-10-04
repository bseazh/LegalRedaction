from __future__ import annotations

import json
from collections import Counter
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    path = root / "test-results/real-annotation-assisted.jsonl"
    records = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    # This is deliberately a disagreement/coverage report, not a precision report.
    result = Counter()
    for record in records:
        for item in record.get("assisted_candidates", []):
            result[item["ai_status"]] += 1
    report = {"status": "simulated_only", "files": len(records), "candidate_counts": dict(result), "warning": "AI-assisted candidates are not human gold labels. Do not call these precision, recall, or F1."}
    output = root / "test-results/real-simulated-assistance.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

