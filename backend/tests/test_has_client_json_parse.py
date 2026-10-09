from app.services.has_client import HaSClient


def test_try_parse_json_object_accepts_json_fence():
    mode, parsed = HaSClient._try_parse_json_object(
        '```json\n{"公司名称":["海南工程服务有限公司"]}\n```'
    )

    assert mode in {"fenced", "substring", "json_repair:fenced", "json_repair:substring"}
    assert parsed == {"公司名称": ["海南工程服务有限公司"]}


def test_try_parse_json_object_extracts_embedded_object():
    mode, parsed = HaSClient._try_parse_json_object(
        '结果如下：{"姓名":["张三"],"电话":["13800138000"]}。'
    )

    assert mode in {"substring", "json_repair:substring"}
    assert parsed == {"姓名": ["张三"], "电话": ["13800138000"]}


def test_try_parse_json_object_repairs_minor_json_damage():
    mode, parsed = HaSClient._try_parse_json_object(
        '{"姓名":["张三",],"公司名称":["海南工程服务有限公司",],}'
    )

    assert mode.startswith("json_repair")
    assert parsed == {"姓名": ["张三"], "公司名称": ["海南工程服务有限公司"]}


def test_ner_json_parse_retries_one_empty_model_response(monkeypatch):
    client = HaSClient(base_url="http://stub:8080/v1")
    responses = iter(["", '{"姓名":["张三"]}'])
    calls = []

    def fake_call_model(*args, **kwargs):
        calls.append((args, kwargs))
        return next(responses)

    monkeypatch.setattr(client, "_call_model", fake_call_model)

    mode, parsed, response = client._call_ner_json_with_retry(
        [{"role": "user", "content": "prompt"}],
        max_tokens=128,
        temperature=0.0,
    )

    assert len(calls) == 2
    assert mode == "direct"
    assert parsed == {"姓名": ["张三"]}
    assert response == '{"姓名":["张三"]}'
