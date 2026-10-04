from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

from .ner import RuleBackend, merge_entities
from .redaction_core import Entity


def load_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def as_key(item: Entity | dict) -> tuple[str, str, int, int]:
    if isinstance(item, dict):
        return (str(item["type"]), str(item["value"]), int(item["start"]), int(item["end"]))
    return (item.type, item.value, int(item.start), int(item.end))


def score(expected: list[dict], predicted: list[Entity]) -> dict:
    gold = {as_key(item) for item in expected}
    guess = {as_key(item) for item in predicted}
    tp = len(gold & guess)
    fp = len(guess - gold)
    fn = len(gold - guess)
    return {"tp": tp, "fp": fp, "fn": fn, "precision": tp / (tp + fp) if tp + fp else 1.0, "recall": tp / (tp + fn) if tp + fn else 1.0}


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate rules/NER/hybrid span-level extraction")
    parser.add_argument("corpus", type=Path)
    parser.add_argument("--output", type=Path, default=Path("test-results/ner-evaluation.json"))
    args = parser.parse_args()
    backend = RuleBackend()
    reports = defaultdict(lambda: {"tp": 0, "fp": 0, "fn": 0})
    per_type = defaultdict(lambda: defaultdict(lambda: {"tp": 0, "fp": 0, "fn": 0}))
    for sample in load_jsonl(args.corpus):
        text = sample["text"]
        gold = sample["entities"]
        rules = backend.recognize(text, list({item["type"] for item in gold}))
        # NER is injected later through the same function signature. Keeping an
        # empty result here makes the baseline report explicit rather than fake.
        variants = {"rules": rules, "ner": [], "hybrid": rules}
        for name, predicted in variants.items():
            result = score(gold, predicted)
            for key in reports[name]: reports[name][key] += result[key]
            for type_id in {item["type"] for item in gold} | {item.type for item in predicted}:
                typed_gold = [item for item in gold if item["type"] == type_id]
                typed_guess = [item for item in predicted if item.type == type_id]
                typed = score(typed_gold, typed_guess)
                for key in per_type[name][type_id]: per_type[name][type_id][key] += typed[key]
    final = {"variants": dict(reports), "per_type": {name: dict(values) for name, values in per_type.items()}, "note": "NER and hybrid are placeholders until a backend is configured."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(final, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(final, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
