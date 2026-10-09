import unittest

try:
    import fitz
except ImportError:
    fitz = None

from service.pdf_redactor import PdfRedactionError, redact_pdf_bytes


@unittest.skipIf(fitz is None, "PyMuPDF is not installed")
class PdfRedactorTests(unittest.TestCase):
    def make_pdf(self, text: str) -> bytes:
        document = fitz.open()
        page = document.new_page()
        page.insert_text((72, 72), text, fontname="china-s", fontsize=12)
        output = document.tobytes()
        document.close()
        return output

    def test_removes_searchable_original_and_inserts_pseudonym(self):
        output, audit = redact_pdf_bytes(self.make_pdf("原告唐三与唐三签约"), [{"type": "PERSON", "value": "唐三"}], "semantic")
        document = fitz.open(stream=output, filetype="pdf")
        try:
            self.assertFalse(document[0].search_for("唐三"))
            self.assertEqual(len(document[0].search_for("人员A")), 2)
        finally:
            document.close()
        self.assertEqual(audit["mapping"]["人员A"]["occurrences"], 2)

    def test_refuses_partial_redaction(self):
        with self.assertRaises(PdfRedactionError):
            redact_pdf_bytes(self.make_pdf("原告唐三"), [{"type": "PERSON", "value": "小舞"}], "semantic")


if __name__ == "__main__":
    unittest.main()
