from __future__ import annotations

from dataclasses import dataclass


PERSON_TYPES = {
    "PERSON",
    "PLAINTIFF",
    "DEFENDANT",
    "APPLICANT",
    "RESPONDENT",
    "ATTORNEY",
    "LEGAL_REPRESENTATIVE",
}
ORGANIZATION_TYPES = {"ORGANIZATION", "COURT", "LAW_FIRM"}

TYPE_LABELS = {
    "PERSON": "人员",
    "ORGANIZATION": "机构",
    "ADDRESS": "地址",
    "DEPARTMENT": "部门",
    "PROJECT": "项目",
    "COURT": "法院",
    "LAW_FIRM": "律所",
    "PHONE": "电话",
    "ID_NUMBER": "证件号",
    "BANK_CARD": "账户",
    "EMAIL": "邮箱",
    "CASE_NUMBER": "案号",
    "CONTRACT_NUMBER": "合同号",
}

NATURAL_NAMES = ("李明", "王芳", "陈晨", "赵宁", "周安", "林悦", "吴桐", "郑远", "许清", "何川")
NATURAL_ORGANIZATIONS = (
    "星河科技有限公司",
    "云岚商贸有限公司",
    "青禾咨询有限公司",
    "远川实业有限公司",
    "明海文化有限公司",
)


def canonical_type(entity_type: str) -> str:
    if entity_type in PERSON_TYPES:
        return "PERSON"
    if entity_type in ORGANIZATION_TYPES:
        return "ORGANIZATION"
    return entity_type


def alpha_index(index: int) -> str:
    """Return spreadsheet-style labels: 1=A, 26=Z, 27=AA."""
    if index < 1:
        raise ValueError("index must be positive")
    result = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        result = chr(65 + remainder) + result
    return result


@dataclass(frozen=True)
class Replacement:
    type: str
    value: str
    replacement: str


def build_replacements(entities: list[dict], mode: str = "semantic") -> list[Replacement]:
    if mode not in {"semantic", "natural"}:
        raise ValueError("replacement mode must be semantic or natural")
    counters: dict[str, int] = {}
    replacements: dict[tuple[str, str], Replacement] = {}
    ordered: list[Replacement] = []
    for entity in entities:
        entity_type = str(entity.get("type", "")).strip().upper()
        value = str(entity.get("value", "")).strip()
        if not entity_type or not value:
            continue
        group = canonical_type(entity_type)
        key = (group, value)
        if key in replacements:
            continue
        counters[group] = counters.get(group, 0) + 1
        number = counters[group]
        label = TYPE_LABELS.get(group, "敏感项")
        replacement = f"{label}{alpha_index(number)}"
        if mode == "natural":
            if group == "PERSON":
                replacement = NATURAL_NAMES[(number - 1) % len(NATURAL_NAMES)]
            elif group == "ORGANIZATION":
                replacement = NATURAL_ORGANIZATIONS[(number - 1) % len(NATURAL_ORGANIZATIONS)]
        item = Replacement(entity_type, value, replacement)
        replacements[key] = item
        ordered.append(item)
    return ordered
