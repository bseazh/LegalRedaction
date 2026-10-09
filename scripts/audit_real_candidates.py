#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from service.quality_audit import audit_result, audit_summary, findings_as_dicts
DEFAULT_INPUTS = [
    ROOT / "reports/real-backend-regression/results/txt_notes.json",
    ROOT / "reports/real-backend-regression/results/docx_short.json",
    ROOT / "reports/real-backend-regression-after-fix/results/docx_legal_roles.json",
    ROOT / "reports/real-backend-regression-fallback/results/docx_long_recording.json",
    ROOT / "reports/real-backend-regression/results/pdf_agreement.json",
    ROOT / "reports/real-backend-regression-after-fix/results/pdf_registration.json",
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "reports/candidate-quality-audit")
    parser.add_argument("inputs", nargs="*", type=Path)
    args = parser.parse_args()
    paths = args.inputs or DEFAULT_INPUTS
    results, findings = [], []
    for path in paths:
        result = json.loads(path.read_text(encoding="utf-8"))
        sample_id = path.stem
        results.append((sample_id, result))
        findings.extend(audit_result(sample_id, result))
    findings.sort(key=lambda item: (-item.score, -item.occurrences, item.sample_id, item.value))
    summary = audit_summary(findings, results)
    payload = {"summary": summary, "queue": findings_as_dicts(findings), "source_files": [str(path) for path in paths]}
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "audit.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Candidate Quality Audit", "", f"Samples: **{summary['samples']}**", f"Entity occurrences: **{summary['entity_occurrences']}**", f"Unique typed values: **{summary['unique_typed_values']}**", f"Risk queue: **{summary['findings']}** ({summary['risk_counts']})", "", "| Risk | Sample | Type | Value | Occurrences | Reasons |", "|---|---|---|---|---:|---|"]
    for item in findings:
        lines.append(f"| {item.risk} | {item.sample_id} | {item.type} | {item.value.replace('|', '\\|')} | {item.occurrences} | {', '.join(item.reasons)} |")
    lines.extend(["", "## Interpretation", "", "- This is a deterministic risk queue, not a precision/recall score.", "- Repeated occurrences are grouped into one review item per entity type and value.", "- High-risk candidates should default to manual review; they are never removed automatically."])
    (args.output / "audit.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
