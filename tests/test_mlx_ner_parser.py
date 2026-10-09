import unittest

from service.mlx_ner import parse_ner_response


class NerResponseParserTests(unittest.TestCase):
    def test_expands_one_value_to_every_source_occurrence(self):
        text = "张伟签字，之后张伟再次确认。"
        entities = parse_ner_response('{"姓名":["张伟"]}', text, ["PERSON"])
        self.assertEqual([(item.start, item.end) for item in entities], [(0, 2), (7, 9)])

    def test_accepts_fenced_json_and_string_value(self):
        entities = parse_ner_response('```json\n{"机构":"华星公司"}\n```', "甲方华星公司", ["ORGANIZATION"])
        self.assertEqual(len(entities), 1)
        self.assertEqual(entities[0].value, "华星公司")

    def test_rejects_hallucinated_value(self):
        entities = parse_ner_response('{"姓名":["李娜"]}', "原告张伟", ["PERSON"])
        self.assertEqual(entities, [])

    def test_role_requires_nearby_role_label(self):
        text = "原告张伟提交材料，另页记载张伟联系电话。"
        entities = parse_ner_response('{"原告":["张伟"]}', text, ["PLAINTIFF"])
        self.assertEqual(len(entities), 1)
        self.assertEqual(entities[0].start, 2)

    def test_requires_complete_json(self):
        with self.assertRaises(ValueError):
            parse_ner_response('{"姓名":["张伟"]', "张伟", ["PERSON"])


if __name__ == "__main__":
    unittest.main()
