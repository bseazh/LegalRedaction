from __future__ import annotations

import json
from pathlib import Path

from .mlx_ner import Qwen3NerBackend, TYPE_NAMES
from .redaction_core import detect_entities, extract_text


SOURCES = [
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/委托合同.docx"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/回复律师函.docx"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/民事起诉状草稿.docx"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/补充协议-final2.pdf"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/整改通知.pdf"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/回单.pdf"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/催款.eml"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/类案检索随手记.txt"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/授权委托书.pdf"),
    Path("/Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/000-Assets/Assets/01_原始材料_请投喂Agent/律师函扫描件.pdf"),
]


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    backend = Qwen3NerBackend(root / "models/qwen3/Qwen3-1.7B-bf16")
    requested = list(TYPE_NAMES)
    output = root / "test-results/real-annotation-candidates.jsonl"
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        for index, source in enumerate(SOURCES, 1):
            text = extract_text(source)
            # Keep model context bounded and preserve global offsets.
            candidates = []
            for offset in range(0, len(text), 1200):
                chunk = text[offset : offset + 1200]
                for entity in backend.recognize(chunk, requested):
                    candidates.append({"type": entity.type, "value": entity.value, "start": offset + entity.start, "end": offset + entity.end, "source": "fp16_ner", "review": "pending"})
            rules = [item.__dict__ | {"review": "pending"} for item in detect_entities(text)]
            record = {
                "id": f"real-{index:02d}",
                "source_path": str(source),
                "format": source.suffix.lower().lstrip("."),
                "text": text,
                "candidates": candidates,
                "rule_candidates": rules,
                "gold_entities": [],
                "review_notes": "",
                "review_status": "pending",
            }
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
            print(record["id"], len(text), len(candidates), len(rules))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
