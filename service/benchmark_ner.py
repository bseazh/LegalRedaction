from __future__ import annotations

import argparse
import json
import resource
import time
import urllib.request
from pathlib import Path


def request(url: str, model: str, text: str, types: list[str]) -> tuple[dict, float]:
    prompt = f"Recognize the following entity types in the text.\nSpecified types:{json.dumps(types, ensure_ascii=False)}\n<text>{text}</text>"
    body = json.dumps({"model": model, "temperature": 0, "max_tokens": 512, "messages": [{"role": "user", "content": prompt}]}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=180) as response:
        payload = json.loads(response.read().decode())
    return payload, time.perf_counter() - start


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark a local Qwen3/OpenAI-compatible NER endpoint")
    parser.add_argument("--url", default="http://127.0.0.1:8080/v1/chat/completions")
    parser.add_argument("--model", default="Qwen3-1.7B-bf16")
    parser.add_argument("--text", default="原告张伟委托北京明德律师事务所，联系电话13800138000，案号（2025）粤0305民初123号。")
    parser.add_argument("--repeat", type=int, default=5)
    parser.add_argument("--output", type=Path, default=Path("test-results/has-benchmark.json"))
    args = parser.parse_args()
    samples = []
    for _ in range(args.repeat):
        try:
            payload, seconds = request(args.url, args.model, args.text, ["姓名", "机构", "电话", "案号"])
            content = payload.get("choices", [{}])[0].get("message", {}).get("content", "")
            samples.append({"ok": True, "seconds": seconds, "content": content})
        except Exception as exc:
            samples.append({"ok": False, "error": str(exc)})
    successful = [item for item in samples if item["ok"]]
    report = {
        "model": args.model,
        "url": args.url,
        "repeat": args.repeat,
        "successful": len(successful),
        "latencies_seconds": [item["seconds"] for item in successful],
        "max_rss_kb": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "samples": samples,
        "note": "Endpoint response must be parsed and checked against gold offsets separately; raw model output is retained only in this local report.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k != "samples"}, ensure_ascii=False, indent=2))
    return 0 if successful else 2


if __name__ == "__main__":
    raise SystemExit(main())
