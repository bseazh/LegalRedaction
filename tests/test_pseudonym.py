import unittest

from service.pseudonym import alpha_index, build_replacements


class PseudonymTests(unittest.TestCase):
    def test_semantic_replacements_are_stable_for_repeated_people(self):
        entities = [
            {"type": "PLAINTIFF", "value": "唐三"},
            {"type": "PERSON", "value": "唐三"},
            {"type": "DEFENDANT", "value": "小舞"},
        ]
        result = build_replacements(entities)
        self.assertEqual([(item.value, item.replacement) for item in result], [("唐三", "人员A"), ("小舞", "人员B")])

    def test_natural_mode_uses_fictitious_names(self):
        result = build_replacements([{"type": "PERSON", "value": "唐三"}], "natural")
        self.assertEqual(result[0].replacement, "李明")

    def test_alpha_index_supports_more_than_twenty_six_entities(self):
        self.assertEqual(alpha_index(27), "AA")


if __name__ == "__main__":
    unittest.main()
