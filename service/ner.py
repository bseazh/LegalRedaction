from __future__ import annotations

import json
import urllib.request
from dataclasses import replace
from typing import Protocol

from .redaction_core import Entity, detect_entities


class NerBackend(Protocol):
    name: str

    def recognize(self, text: str, entity_types: list[str]) -> list[Entity]: ...


class RuleBackend:
    name = "rules"

    def recognize(self, text: str, entity_types: list[str]) -> list[Entity]:
        allowed = set(entity_types)
        return [item for item in detect_entities(text) if item.type in allowed]


class OpenAICompatibleBackend:
    """Adapter for a local Qwen3/vLLM-compatible chat endpoint.

    The model is instructed to return JSON only. This adapter deliberately does
    not assume a particular model name or runtime, so a future Transformers
    backend can replace it without changing the evaluation pipeline.
    """

    name = "ner"

    def __init__(self, url: str, model: str, timeout: float = 120.0):
        self.url = url
        self.model = model
        self.timeout = timeout

    def recognize(self, text: str, entity_types: list[str]) -> list[Entity]:
        prompt = (
            "Extract only the requested entities from the Chinese legal text. "
            "Return a JSON array and no markdown. Each item must contain "
            "type, value, start, end, confidence. Offsets are Python string "
            "offsets in the supplied text. Requested types: "
            f"{json.dumps(entity_types, ensure_ascii=False)}\n\nTEXT:\n{text}"
        )
        body = json.dumps({"model": self.model, "temperature": 0, "messages": [{"role": "user", "content": prompt}]}).encode()
        request = urllib.request.Request(self.url, data=body, headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
        content = payload["choices"][0]["message"]["content"]
        if isinstance(content, list):
            content = "".join(str(part.get("text", "")) for part in content if isinstance(part, dict))
        items = json.loads(str(content).strip().replace("```json", "").replace("```", "").strip())
        result: list[Entity] = []
        for item in items:
            value = str(item["value"])
            start = int(item["start"])
            end = int(item["end"])
            if text[start:end] != value:
                # Model offsets are not trusted; recover an unambiguous occurrence.
                start = text.find(value)
                end = start + len(value) if start >= 0 else -1
            if start >= 0 and end > start:
                result.append(Entity(str(item["type"]), value, start, end, float(item.get("confidence", 0.5)), "ner"))
        return result


def merge_entities(rule_entities: list[Entity], ner_entities: list[Entity]) -> list[Entity]:
    """Merge deterministic rules with semantic NER, preferring rules on overlap."""
    all_entities = [*rule_entities, *ner_entities]
    all_entities.sort(key=lambda item: (-item.confidence, 0 if item.source == "rule" else 1, -(item.end - item.start), item.start))
    selected: list[Entity] = []
    for entity in all_entities:
        if any(entity.start < item.end and item.start < entity.end for item in selected):
            continue
        selected.append(entity)
    return sorted(selected, key=lambda item: item.start)
