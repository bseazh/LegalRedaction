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
    "ADDRESS": "地址",
    "DEPARTMENT": "部门",
    "PROJECT": "项目名",
    "COURT": "法院",
    "LAW_FIRM": "律师事务所",
    "PLAINTIFF": "原告",
    "DEFENDANT": "被告",
    "APPLICANT": "申请人",
    "RESPONDENT": "被申请人",
    "ATTORNEY": "代理人",
    "LEGAL_REPRESENTATIVE": "法定代表人",
}
ROLE_LABELS = {key: value for key, value in TYPE_NAMES.items() if key in {"PLAINTIFF", "DEFENDANT", "APPLICANT", "RESPONDENT", "ATTORNEY", "LEGAL_REPRESENTATIVE"}}


class Qwen3NerBackend:
    name = "qwen3-1.7b-bf16"

    def __init__(self, model_path: str | Path):
        self.model, self.tokenizer = load(str(model_path))

    def recognize(self, text: str, entity_types: list[str]) -> list[Entity]:
        requested = [TYPE_NAMES.get(item, item) for item in entity_types]
        body = ("你是中文法律文书实体抽取器。请提取文本中所有出现的实体，不要只返回代表性实体，也不要遗漏重复出现的同一姓名。"
                "机构、法院、律师事务所、部门、项目名必须分开。原告/被告/申请人/被申请人/代理人/法定代表人等法律角色的值只返回对应的人名或机构名，不要把角色词混入值。"
                "只返回 JSON 对象，不要解释、不要思考过程、不要 Markdown。"
                f"JSON 的键只能是这些类型：{json.dumps(requested, ensure_ascii=False)}。"
                "每个键的值必须是字符串数组；没有实体时返回空数组；同一实体在文本中出现多次时数组中重复返回。\n"
                f"文本：{text}")
        try:
            prompt = self.tokenizer.apply_chat_template([{"role": "user", "content": body}], tokenize=False, add_generation_prompt=True, enable_thinking=False)
        except TypeError:
            prompt = f"<|im_start|>user\n{body}<|im_end|>\n<|im_start|>assistant\n"
        chunks: list[str] = []
        for response in stream_generate(self.model, self.tokenizer, prompt, max_tokens=160, sampler=greedy_sampler):
            chunks.append(response.text)
        try:
            raw = "".join(chunks).strip()
            raw = raw.replace("<think>", "").replace("</think>", "")
            if "```" in raw:
                raw = raw.replace("```json", "").replace("```", "").strip()
            data = json.loads(raw)
        except json.JSONDecodeError:
            return []
        inverse = {value: key for key, value in TYPE_NAMES.items()}
        entities: list[Entity] = []
        for label, values in data.items() if isinstance(data, dict) else []:
            type_id = inverse.get(label, label)
            if type_id not in entity_types or not isinstance(values, list):
                continue
            if isinstance(values, str):
                values = [values]
            for value in values:
                if not isinstance(value, str):
                    continue
                starts = [i for i in range(len(text)) if text.startswith(value, i)]
                if len(starts) != 1:
                    continue
                start = starts[0]
                if type_id in ROLE_LABELS:
                    context = text[max(0, start - 8):min(len(text), start + len(value) + 8)]
                    if ROLE_LABELS[type_id] not in context:
                        continue
                entities.append(Entity(type_id, value, start, start + len(value), 0.9, "ner"))
        return entities


def recognize_chunked(backend: Qwen3NerBackend, text: str, entity_types: list[str], chunk_chars: int = 2400, overlap: int = 200) -> list[Entity]:
    """Run NER over bounded windows and restore document-global offsets."""
    step = max(1, chunk_chars - overlap)
    result: list[Entity] = []
    seen: set[tuple[str, str, int, int]] = set()
    for offset in range(0, len(text), step):
        chunk = text[offset:offset + chunk_chars]
        if chunk.strip():
            for entity in backend.recognize(chunk, entity_types):
                item = Entity(entity.type, entity.value, offset + entity.start, offset + entity.end, entity.confidence, entity.source)
                key = (item.type, item.value, item.start, item.end)
                if key not in seen:
                    seen.add(key)
                    result.append(item)
        if offset + chunk_chars >= len(text):
            break
    return sorted(result, key=lambda item: (item.start, item.end))
