from __future__ import annotations

import json
from pathlib import Path

from mlx_lm import load
from mlx_lm.generate import stream_generate
from mlx_lm.sample_utils import greedy_sampler

from .redaction_core import Entity


TYPE_NAMES = {
    "PERSON": "姓名",
    "ORGANIZATION": "机构",
    "PHONE": "电话",
    "ID_NUMBER": "身份证号",
    "BANK_CARD": "银行卡号",
    "ADDRESS": "地址",
    "CASE_NUMBER": "案号",
    "CONTRACT_NUMBER": "合同编号",
    "EMAIL": "邮箱",
}


class MlxNerBackend:
    name = "mlx-fp16"

    def __init__(self, model_path: str | Path):
        self.model, self.tokenizer = load(str(model_path))

    def recognize(self, text: str, entity_types: list[str]) -> list[Entity]:
        requested = [TYPE_NAMES.get(item, item) for item in entity_types]
        body = f"Recognize the following entity types in the text.\nSpecified types:{json.dumps(requested, ensure_ascii=False)}\n<text>{text}</text>"
        prompt = f"<|im_start|>user\n{body}<|im_end|>\n<|im_start|>assistant\n"
        chunks: list[str] = []
        for response in stream_generate(self.model, self.tokenizer, prompt, max_tokens=160, sampler=greedy_sampler):
            chunks.append(response.text)
        try:
            data = json.loads("".join(chunks).strip())
        except json.JSONDecodeError:
            return []
        inverse = {value: key for key, value in TYPE_NAMES.items()}
        entities: list[Entity] = []
        for label, values in data.items() if isinstance(data, dict) else []:
            type_id = inverse.get(label, label)
            if type_id not in entity_types or not isinstance(values, list):
                continue
            for value in values:
                if not isinstance(value, str):
                    continue
                starts = [i for i in range(len(text)) if text.startswith(value, i)]
                if len(starts) != 1:
                    continue
                start = starts[0]
                entities.append(Entity(type_id, value, start, start + len(value), 0.9, "ner"))
        return entities

