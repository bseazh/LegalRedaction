import unittest

from service.quality_audit import audit_result


class QualityAuditTests(unittest.TestCase):
    def test_groups_repeated_speaker_label(self):
        text = "男1：你好。男1：确认。"
        result = {"text": text, "entities": [
            {"type": "PERSON", "value": "男1", "start": 0, "end": 2},
            {"type": "PERSON", "value": "男1", "start": 6, "end": 8},
        ]}
        finding = audit_result("speaker", result)[0]
        self.assertEqual(finding.risk, "high")
        self.assertEqual(finding.occurrences, 2)
        self.assertIn("speaker_or_title_as_person", finding.reasons)

    def test_flags_role_without_nearby_label(self):
        result = {"text": "合同由张伟签署。", "entities": [{"type": "PLAINTIFF", "value": "张伟", "start": 3, "end": 5}]}
        finding = audit_result("role", result)[0]
        self.assertIn("role_context_mismatch", finding.reasons)

    def test_flags_generic_project_term(self):
        result = {"text": "交付原装货。", "entities": [{"type": "PROJECT", "value": "原装货", "start": 2, "end": 5}]}
        finding = audit_result("project", result)[0]
        self.assertEqual(finding.risk, "high")

    def test_clean_person_does_not_enter_queue(self):
        result = {"text": "张伟签署合同。", "entities": [{"type": "PERSON", "value": "张伟", "start": 0, "end": 2}]}
        self.assertEqual(audit_result("clean", result), [])


if __name__ == "__main__":
    unittest.main()
