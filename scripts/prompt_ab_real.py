#!/usr/bin/env python3
from __future__ import annotations

import json
import argparse
import sys
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from service.mlx_ner import Qwen3NerBackend, TYPE_NAMES
from service.quality_audit import audit_result


SAMPLES = [
    ("docx_legal_roles", ROOT / "reports/real-backend-regression-after-fix/results/docx_legal_roles.json", 1200, ["刘一帆", "沈岚", "高启程", "上海灵犀数据科技有限公司（模拟）", "杭州智云数字科技有限公司（模拟）", "WMS定制开发合同"]),
    ("pdf_registration", ROOT / "reports/real-backend-regression-after-fix/results/pdf_registration.json", 2208, ["孔霞"]),
    ("docx_long_recording_part1", ROOT / "reports/real-backend-regression-fallback/results/docx_long_recording.json", 6000, ["周峰", "朱莉", "朱红日", "覃响林", "朱红兵"]),
]


def run_variant(backend: Qwen3NerBackend, text: str, variant: str) -> dict:
    started = time.perf_counter()
    entities = backend.recognize(text, list(TYPE_NAMES), prompt_variant=variant)
    result = {"text": text, "entities": [entity.__dict__ | {"policy": "manual_review"} for entity in entities]}
    findings = audit_result("ab", result)
    values = Counter((entity.type, entity.value) for entity in entities)
    return {
        "variant": variant, "seconds": round(time.perf_counter() - started, 3), "entity_occurrences": len(entities),
        "unique_typed_values": len(values), "types": dict(Counter(entity.type for entity in entities)),
        "risk_findings": len(findings), "high_risk_findings": sum(item.risk == "high" for item in findings),
        "high_risk_values": [{"type": item.type, "value": item.value, "reasons": item.reasons} for item in findings if item.risk == "high"],
        "typed_values": [{"type": type_id, "value": value, "occurrences": count} for (type_id, value), count in sorted(values.items())],
        "diagnostics": {"response_valid": backend.last_response_valid, "response_error": backend.last_response_error, "conservative_filtered": backend.last_filtered_count},
    }


def add_comparison(row: dict, anchors: list[str]) -> None:
    by_variant = {item["variant"]: item for item in row["variants"]}
    a_values = {(item["type"], item["value"]) for item in by_variant["A"]["typed_values"]}
    b_values = {(item["type"], item["value"]) for item in by_variant["B"]["typed_values"]}
    b_plain_values = {value for _, value in b_values}
    row["comparison"] = {
        "removed_by_b": [{"type": type_id, "value": value} for type_id, value in sorted(a_values - b_values)],
        "added_by_b": [{"type": type_id, "value": value} for type_id, value in sorted(b_values - a_values)],
        "anchor_values": anchors,
        "b_anchor_retained": [value for value in anchors if value in b_plain_values],
        "b_anchor_retention": sum(value in b_plain_values for value in anchors) / len(anchors),
    }


def write_report(output: Path, model_name: str, rows: list[dict]) -> None:
    anchors_by_id = {sample_id: anchors for sample_id, _, _, anchors in SAMPLES}
    for row in rows:
        add_comparison(row, anchors_by_id[row["id"]])
    output = ROOT / "reports/prompt-ab-real"
    output.mkdir(parents=True, exist_ok=True)
    payload = {"model": model_name, "samples": rows, "decision": "keep_a_with_quality_audit", "note": "A is the current prompt. B adds conservative legal-name and project-name exclusions. B is not promoted because it removes a valid project anchor. No redaction is triggered by this experiment."}
    (output / "comparison.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Prompt A/B Real-Text Comparison", "", "| Sample | Variant | Chars | Occurrences | Unique values | Risk findings | High risk | Anchors retained | Seconds |", "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    for row in rows:
        for item in row["variants"]:
            retained = f"{len(row['comparison']['b_anchor_retained'])}/{len(row['comparison']['anchor_values'])}" if item["variant"] == "B" else "baseline"
            lines.append(f"| {row['id']} | {item['variant']} | {row['chars']} | {item['entity_occurrences']} | {item['unique_typed_values']} | {item['risk_findings']} | {item['high_risk_findings']} | {retained} | {item['seconds']} |")
    lines.extend(["", "## Value Differences", ""])
    for row in rows:
        removed = ", ".join(f"{item['type']}:{item['value']}" for item in row["comparison"]["removed_by_b"]) or "none"
        added = ", ".join(f"{item['type']}:{item['value']}" for item in row["comparison"]["added_by_b"]) or "none"
        lines.extend([f"- `{row['id']}` removed by B: {removed}", f"- `{row['id']}` added by B: {added}"])
    lines.extend(["", "## Interpretation", "", "- This is a prompt-behavior comparison, not a gold-label precision/recall score.", "- Lower high-risk counts are preferred only when important legal entities are not lost.", "- Every candidate remains subject to local offset validation and human review."])
    (output / "comparison.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report-only", action="store_true")
    args = parser.parse_args()
    output = ROOT / "reports/prompt-ab-real"
    if args.report_only:
        payload = json.loads((output / "comparison.json").read_text(encoding="utf-8"))
        write_report(output, payload["model"], payload["samples"])
        return 0
    backend = Qwen3NerBackend(ROOT / "models/qwen3/Qwen3-1.7B-bf16")
    rows = []
    for sample_id, path, limit, anchors in SAMPLES:
        source = json.loads(path.read_text(encoding="utf-8"))
        text = source["text"][:limit]
        row = {"id": sample_id, "chars": len(text), "source": str(path), "variants": []}
        for variant in ("A", "B"):
            result = run_variant(backend, text, variant)
            row["variants"].append(result)
            print(f"[{sample_id}] {variant}: {result}", flush=True)
        rows.append(row)
    write_report(output, backend.name, rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
