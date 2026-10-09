from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
import re


ROLE_WORDS = {
    "PLAINTIFF": ("原告",),
    "DEFENDANT": ("被告",),
    "APPLICANT": ("申请人",),
    "RESPONDENT": ("被申请人",),
    "ATTORNEY": ("代理人", "代理律师", "律师"),
    "LEGAL_REPRESENTATIVE": ("法定代表人", "法定代表", "法人"),
}
PERSON_TYPES = {"PERSON", *ROLE_WORDS}
TITLE_PATTERN = re.compile(r"^(?:男|女)\d+$|^[\u4e00-\u9fff]{1,3}(?:总|经理|主任|老师|律师|先生|女士|工|董)$")
COMMON_PERSON_FALSE_POSITIVES = {
    "本人", "对方", "双方", "甲方", "乙方", "原告", "被告", "申请人", "代理人", "联系人",
    "员工", "客户", "领导", "同事", "法官", "律师", "男方", "女方", "公司", "法院",
}
GENERIC_PROJECT_TERMS = {
    "原装货", "补充协议", "合作协议", "采购合同", "销售合同", "服务合同", "库存同步异常",
    "测试", "项目", "合同", "协议", "系统", "产品", "材料", "货物", "问题",
}
ORG_SUFFIXES = ("公司", "集团", "事务所", "法院", "检察院", "委员会", "中心", "医院", "学校", "银行", "政府", "局", "厅", "部")


@dataclass
class AuditFinding:
    risk: str
    score: int
    sample_id: str
    type: str
    value: str
    occurrences: int
    reasons: list[str]
    context_match_rate: float | None
    other_types: list[str]
    positions: list[int]


def _role_context_matches(text: str, entity: dict, window: int = 16) -> bool:
    words = ROLE_WORDS.get(entity.get("type"))
    if not words:
        return True
    start, end = entity["start"], entity["end"]
    context = text[max(0, start - window):min(len(text), end + window)]
    return any(word in context for word in words)


def audit_result(sample_id: str, result: dict) -> list[AuditFinding]:
    text, entities = result.get("text", ""), result.get("entities", [])
    grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
    value_types: dict[str, set[str]] = defaultdict(set)
    for entity in entities:
        grouped[(entity.get("type", "UNKNOWN"), entity.get("value", ""))].append(entity)
        value_types[entity.get("value", "")].add(entity.get("type", "UNKNOWN"))

    findings = []
    for (type_id, value), occurrences in grouped.items():
        score, reasons = 0, []
        stripped = value.strip()
        if type_id in PERSON_TYPES:
            if len(stripped) < 2:
                score += 80; reasons.append("person_too_short")
            if stripped in COMMON_PERSON_FALSE_POSITIVES:
                score += 90; reasons.append("common_word_as_person")
            if TITLE_PATTERN.fullmatch(stripped):
                score += 75; reasons.append("speaker_or_title_as_person")
            if re.fullmatch(r"[\u4e00-\u9fff]{5,}", stripped):
                score += 35; reasons.append("unusually_long_chinese_person")
        if type_id == "PROJECT":
            if stripped in GENERIC_PROJECT_TERMS:
                score += 75; reasons.append("generic_term_as_project")
            if len(stripped) < 4:
                score += 35; reasons.append("project_too_short")
        if type_id in {"ORGANIZATION", "COURT", "LAW_FIRM"} and not stripped.endswith(ORG_SUFFIXES):
            score += 25; reasons.append("organization_without_expected_suffix")

        role_matches = [_role_context_matches(text, entity) for entity in occurrences]
        match_rate = sum(role_matches) / len(role_matches) if type_id in ROLE_WORDS else None
        if match_rate is not None and match_rate < 1:
            penalty = 80 if match_rate == 0 else 45
            score += penalty; reasons.append("role_context_mismatch")

        other_types = sorted(value_types[value] - {type_id})
        if other_types:
            score += 35; reasons.append("same_value_multiple_types")
        if len(occurrences) >= 100:
            score += 20; reasons.append("extreme_repetition")
        elif len(occurrences) >= 20:
            score += 10; reasons.append("high_repetition")

        if score:
            risk = "high" if score >= 70 else "medium" if score >= 35 else "low"
            findings.append(AuditFinding(
                risk=risk, score=min(score, 100), sample_id=sample_id, type=type_id, value=value,
                occurrences=len(occurrences), reasons=reasons, context_match_rate=match_rate,
                other_types=other_types, positions=[item["start"] for item in occurrences[:8]],
            ))
    return sorted(findings, key=lambda item: (-item.score, -item.occurrences, item.type, item.value))


def audit_summary(findings: list[AuditFinding], results: list[tuple[str, dict]]) -> dict:
    unique_values = {(entity.get("type"), entity.get("value")) for _, result in results for entity in result.get("entities", [])}
    occurrences = sum(len(result.get("entities", [])) for _, result in results)
    risks = Counter(item.risk for item in findings)
    reasons = Counter(reason for item in findings for reason in item.reasons)
    return {
        "samples": len(results), "entity_occurrences": occurrences, "unique_typed_values": len(unique_values),
        "findings": len(findings), "risk_counts": dict(risks), "reason_counts": dict(reasons),
        "high_risk_occurrences": sum(item.occurrences for item in findings if item.risk == "high"),
    }


def findings_as_dicts(findings: list[AuditFinding]) -> list[dict]:
    return [asdict(item) for item in findings]
