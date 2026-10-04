from __future__ import annotations

import json
import resource
import time
from pathlib import Path

from mlx_lm import load
from mlx_lm.generate import stream_generate
from mlx_lm.sample_utils import greedy_sampler


MODEL = Path(__file__).resolve().parents[1] / "models/has/HaS_Text_0209_0.6B"
TEXT = "原告张伟委托北京明德律师事务所，联系电话13800138000，案号（2025）粤0305民初123号。"
TYPES = ["姓名", "机构", "电话", "案号"]
EXPECTED = {
    "姓名": ["张伟"],
    "机构": ["北京明德律师事务所"],
    "电话": ["13800138000"],
    "案号": ["（2025）粤0305民初123号"],
}


def prompt_for(text: str) -> str:
    # HaS's chat template is required; raw completion causes the base model to
    # continue the document instead of returning NER JSON.
    body = f"Recognize the following entity types in the text.\nSpecified types:{json.dumps(TYPES, ensure_ascii=False)}\n<text>{text}</text>"
    return f"<|im_start|>user\n{body}<|im_end|>\n<|im_start|>assistant\n"


def parse_and_validate(raw: str, text: str) -> dict:
    errors: list[str] = []
    try:
        parsed = json.loads(raw.strip())
    except json.JSONDecodeError as exc:
        return {"valid": False, "errors": [f"invalid_json:{exc.msg}"], "entities": {}}
    if not isinstance(parsed, dict):
        return {"valid": False, "errors": ["result_not_object"], "entities": {}}
    entities: dict[str, list[dict]] = {}
    for type_id, values in parsed.items():
        if type_id not in TYPES:
            errors.append(f"unexpected_type:{type_id}")
            continue
        if not isinstance(values, list):
            errors.append(f"values_not_list:{type_id}")
            continue
        entities[type_id] = []
        for value in values:
            if not isinstance(value, str):
                errors.append(f"value_not_string:{type_id}")
                continue
            starts = [i for i in range(len(text)) if text.startswith(value, i)]
            if not starts:
                errors.append(f"value_not_in_text:{type_id}:{value}")
                continue
            if len(starts) > 1:
                errors.append(f"ambiguous_value:{type_id}:{value}")
            start = starts[0]
            entities[type_id].append({"value": value, "start": start, "end": start + len(value)})
    expected_pairs = {(kind, value) for kind, values in EXPECTED.items() for value in values}
    actual_pairs = {(kind, item["value"]) for kind, values in entities.items() for item in values}
    return {
        "valid": not errors,
        "errors": errors,
        "entities": entities,
        "exact_matches": len(expected_pairs & actual_pairs),
        "expected_count": len(expected_pairs),
        "false_positive_count": len(actual_pairs - expected_pairs),
    }


def main() -> int:
    model, tokenizer = load(str(MODEL))
    prompt = prompt_for(TEXT)
    results = []
    load_rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    for index in range(10):
        started = time.perf_counter()
        chunks = []
        last = None
        for response in stream_generate(model, tokenizer, prompt, max_tokens=80, sampler=greedy_sampler):
            chunks.append(response.text)
            last = response
        elapsed = time.perf_counter() - started
        raw = "".join(chunks)
        checked = parse_and_validate(raw, TEXT)
        results.append({
            "run": index + 1,
            "seconds": elapsed,
            "prompt_tokens": getattr(last, "prompt_tokens", None),
            "generation_tokens": getattr(last, "generation_tokens", None),
            "prompt_tps": getattr(last, "prompt_tps", None),
            "generation_tps": getattr(last, "generation_tps", None),
            "model_peak_memory_gb": getattr(last, "peak_memory", None),
            **checked,
        })
    report = {
        "model": str(MODEL),
        "runtime": "MLX/MLX-LM",
        "device": "Apple M2 16GB",
        "runs": results,
        "successful_runs": sum(item["valid"] for item in results),
        "process_maxrss_raw": max(load_rss, resource.getrusage(resource.RUSAGE_SELF).ru_maxrss),
        "note": "Synthetic text only. Model output is validated before any redaction; no raw response is persisted.",
    }
    output = Path("test-results/has-m2-fp16.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = {k: report[k] for k in ["runtime", "device", "successful_runs", "process_maxrss_raw"]}
    summary["latencies"] = [round(item["seconds"], 3) for item in results]
    summary["generation_tps"] = [item["generation_tps"] for item in results]
    summary["exact_matches"] = [item["exact_matches"] for item in results]
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if report["successful_runs"] == 10 else 2


if __name__ == "__main__":
    raise SystemExit(main())

