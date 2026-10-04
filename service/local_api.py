from __future__ import annotations

import json
import base64
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from .mlx_ner import MlxNerBackend, TYPE_NAMES
from .ner import merge_entities
from .redaction_core import detect_entities, extract_text, tokenize

ROOT = Path(__file__).resolve().parents[1]
HOST, PORT = "127.0.0.1", 8766
MODEL = ROOT / "models/has/HaS_Text_0209_0.6B"
_backend = None
_lock = threading.Lock()


def backend() -> MlxNerBackend:
    global _backend
    with _lock:
        if _backend is None:
            _backend = MlxNerBackend(MODEL)
        return _backend


def analyze(path: Path) -> dict:
    text = extract_text(path)
    rules = detect_entities(text)
    ner = backend().recognize(text, list(TYPE_NAMES))
    entities = merge_entities(rules, ner)
    return {"path": str(path), "name": path.name, "text": text, "entities": [entity.__dict__ for entity in entities], "supported_types": list(TYPE_NAMES)}


class Handler(BaseHTTPRequestHandler):
    def send_json(self, status: int, payload: object) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status); self.send_header("Content-Type", "application/json; charset=utf-8"); self.send_header("Access-Control-Allow-Origin", "*"); self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS"); self.send_header("Access-Control-Allow-Headers", "Content-Type"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)

    def do_OPTIONS(self) -> None:
        self.send_response(204); self.send_header("Access-Control-Allow-Origin", "*"); self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS"); self.send_header("Access-Control-Allow-Headers", "Content-Type"); self.send_header("Access-Control-Max-Age", "600"); self.end_headers()

    def do_GET(self) -> None:
        if self.path == "/health": self.send_json(200, {"ok": True, "runtime": "MLX", "model": str(MODEL)}); return
        self.send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path not in {"/analyze", "/analyze-upload"}: self.send_json(404, {"error": "not found"}); return
        try:
            length = int(self.headers.get("Content-Length", "0")); payload = json.loads(self.rfile.read(length))
            if self.path == "/analyze-upload":
                name = Path(str(payload.get("name", "upload.txt"))).name
                suffix = Path(name).suffix.lower()
                if suffix not in {".txt", ".md", ".eml", ".docx", ".pdf"}: raise ValueError("unsupported file type")
                raw = base64.b64decode(str(payload["data"]), validate=True)
                with tempfile.NamedTemporaryFile(prefix="legalredaction-", suffix=suffix, delete=False) as temporary:
                    temporary.write(raw); temp_path = Path(temporary.name)
                try:
                    result = analyze(temp_path)
                    result["name"] = name
                    result["path"] = "local-upload"
                finally:
                    temp_path.unlink(missing_ok=True)
                self.send_json(200, result)
            else:
                path = Path(str(payload["path"])).expanduser().resolve()
                if not path.is_file(): raise ValueError("file not found")
                self.send_json(200, analyze(path))
        except Exception as exc:
            self.send_json(400, {"error": str(exc)})

    def log_message(self, *_args) -> None: return


def main() -> None:
    print(f"LegalRedaction local API: http://{HOST}:{PORT}")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__": main()
