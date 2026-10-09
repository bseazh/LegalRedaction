from __future__ import annotations

import asyncio

import fitz

from app.models.schemas import Entity, ReplacementMode
from app.services.redaction.replacement_strategy import RedactionContext
from app.services.redaction.text_redactor import TextRedactorMixin


def _entity(text: str, entity_type: str = "PERSON", entity_id: str = "e1") -> Entity:
    return Entity(id=entity_id, text=text, type=entity_type, start=0, end=len(text), selected=True)


def test_pseudonym_mode_reuses_one_fictional_name() -> None:
    context = RedactionContext(ReplacementMode.PSEUDONYM)
    first = context.get_replacement(_entity("唐三"))
    second = context.get_replacement(_entity("唐三", entity_id="e2"))
    other = context.get_replacement(_entity("小舞", entity_id="e3"))

    assert first == "林安然"
    assert second == first
    assert other == "周知远"


def test_pdf_replacement_remains_visible_and_searchable(tmp_path) -> None:
    source = tmp_path / "source.pdf"
    output = tmp_path / "output.pdf"
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), "唐三与唐三签约", fontname="china-s", fontsize=12)
    document.save(source)
    document.close()

    redactor = TextRedactorMixin()
    context = RedactionContext(ReplacementMode.PSEUDONYM)
    count = asyncio.run(
        redactor._redact_pdf_text(str(source), str(output), [_entity("唐三")], context)
    )

    result = fitz.open(output)
    try:
        assert count == 2
        assert result[0].search_for("唐三") == []
        assert len(result[0].search_for("林安然")) == 2
    finally:
        result.close()
