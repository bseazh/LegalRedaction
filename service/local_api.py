from __future__ import annotations

import json
import base64
import logging
import time
import tempfile
import threading
import traceback
import uuid
import os
from logging.handlers import RotatingFileHandler
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from .mlx_ner import Qwen3NerBackend, TYPE_NAMES
from .ner import merge_entities
from .redaction_core import Entity, detect_entities, extract_text, tokenize

ROOT = Path(os.environ.get("LEGALREDACTION_ROOT", Path(__file__).resolve().parents[1])).resolve()
HOST, PORT = "127.0.0.1", 8766
MODEL = Path(os.environ.get("LEGALREDACTION_MODEL_DIR", ROOT / "models/qwen3/Qwen3-1.7B-bf16")).resolve()
LOG_DIR = Path(os.environ.get("LEGALREDACTION_LOG_DIR", ROOT / "logs")).resolve()
LOG_FILE = LOG_DIR / "legalredaction.log"
LOG_DIR.mkdir(parents=True, exist_ok=True)
logger = logging.getLogger("legalredaction.api")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = RotatingFileHandler(LOG_FILE, maxBytes=2 * 1024 * 1024, backupCount=3, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
_backend = None
_lock = threading.Lock()
_inference_lock = threading.Lock()
_jobs: dict[str, dict] = {}
_jobs_lock = threading.Lock()
NER_CHUNK_CHARS = 6000
NER_CHUNK_OVERLAP = 300
POLICY = {
    "PERSON": "must_redact", "PHONE": "must_redact", "ID_NUMBER": "must_redact", "BANK_CARD": "must_redact", "ADDRESS": "must_redact", "EMAIL": "must_redact",
    "ORGANIZATION": "manual_review", "DEPARTMENT": "manual_review", "PROJECT": "manual_review", "COURT": "manual_review", "LAW_FIRM": "manual_review",
    "PLAINTIFF": "must_redact", "DEFENDANT": "must_redact", "APPLICANT": "must_redact", "RESPONDENT": "must_redact", "ATTORNEY": "must_redact", "LEGAL_REPRESENTATIVE": "must_redact",
    "CASE_NUMBER": "do_not_redact", "CONTRACT_NUMBER": "do_not_redact",
}


def backend() -> Qwen3NerBackend:
    global _backend
    with _lock:
        if _backend is None:
            logger.info("model_load_start path=%s", MODEL)
            _backend = Qwen3NerBackend(MODEL)
            logger.info("model_load_done")
        return _backend


def analyze(path: Path, job_id: str | None = None) -> dict:
    started = time.perf_counter()
    logger.info("analyze_start name=%s suffix=%s size=%d", path.name, path.suffix.lower(), path.stat().st_size)
    text = extract_text(path)
    logger.info("extract_done name=%s chars=%d", path.name, len(text))
    rules = detect_entities(text)
    logger.info("rules_done name=%s entities=%d", path.name, len(rules))
    queue_started = time.perf_counter()
    logger.info("ner_queue_wait name=%s", path.name)
    with _inference_lock:
        logger.info("ner_queue_acquired name=%s wait_ms=%d", path.name, round((time.perf_counter() - queue_started) * 1000))
        ner = []
        step = NER_CHUNK_CHARS - NER_CHUNK_OVERLAP
        chunks = max(1, (max(0, len(text) - NER_CHUNK_OVERLAP) + step - 1) // step)
        logger.info("ner_chunks_start name=%s chunks=%d chunk_chars=%d", path.name, chunks, NER_CHUNK_CHARS)
        seen = set()
        for chunk_index, offset in enumerate(range(0, len(text), step), start=1):
            chunk = text[offset : offset + NER_CHUNK_CHARS]
            if not chunk.strip():
                continue
            if job_id:
                with _jobs_lock:
                    _jobs[job_id].update({"status": "running", "phase": "ner", "chunk": chunk_index, "chunks": chunks, "progress": min(95, 30 + round(chunk_index * 65 / chunks)), "message": f"模型识别中：第 {chunk_index} / {chunks} 段"})
            for entity in backend().recognize(chunk, list(TYPE_NAMES)):
                start, end = offset + entity.start, offset + entity.end
                key = (entity.type, start, end, entity.value)
                if key not in seen:
                    seen.add(key)
                    ner.append(Entity(entity.type, entity.value, start, end, entity.confidence, entity.source))
            if offset + NER_CHUNK_CHARS >= len(text):
                break
        logger.info("ner_chunks_done name=%s chunks=%d unique_entities=%d", path.name, chunks, len(ner))
    logger.info("ner_done name=%s entities=%d elapsed_ms=%d", path.name, len(ner), round((time.perf_counter() - started) * 1000))
    entities = merge_entities(rules, ner)
    logger.info("analyze_done name=%s entities=%d elapsed_ms=%d", path.name, len(entities), round((time.perf_counter() - started) * 1000))
    payload_entities = [entity.__dict__ | {"policy": POLICY.get(entity.type, "manual_review")} for entity in entities]
    return {"path": str(path), "name": path.name, "text": text, "entities": payload_entities, "supported_types": list(TYPE_NAMES), "policy": POLICY}


def run_job(job_id: str, name: str, raw: bytes, suffix: str) -> None:
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(prefix="legalredaction-", suffix=suffix, delete=False) as temporary:
            temporary.write(raw); temp_path = Path(temporary.name)
        with _jobs_lock:
            _jobs[job_id].update({"phase": "extract", "message": "正在提取文本"})
        result = analyze(temp_path, job_id)
        result["name"] = name; result["path"] = "local-upload"
        with _jobs_lock:
            _jobs[job_id].update({"status": "done", "phase": "done", "progress": 100, "message": f"识别完成：{len(result['entities'])} 个候选", "result": result})
        logger.info("job_done id=%s name=%s entities=%d", job_id, name, len(result["entities"]))
    except Exception as exc:
        logger.error("job_error id=%s name=%s type=%s error=%s\n%s", job_id, name, type(exc).__name__, exc, traceback.format_exc())
        with _jobs_lock:
            _jobs[job_id].update({"status": "error", "phase": "error", "message": str(exc)})
    finally:
        if temp_path: temp_path.unlink(missing_ok=True)


class Handler(BaseHTTPRequestHandler):
    def send_json(self, status: int, payload: object) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status); self.send_header("Content-Type", "application/json; charset=utf-8"); self.send_header("Access-Control-Allow-Origin", "*"); self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS"); self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Request-ID"); self.send_header("Access-Control-Allow-Private-Network", "true"); self.send_header("X-Request-ID", getattr(self, "_request_id", "")); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)

    def do_OPTIONS(self) -> None:
        logger.info("cors_preflight path=%s origin=%s requested_headers=%s private_network=%s", self.path, self.headers.get("Origin", ""), self.headers.get("Access-Control-Request-Headers", ""), self.headers.get("Access-Control-Request-Private-Network", ""))
        self.send_response(204); self.send_header("Access-Control-Allow-Origin", "*"); self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS"); self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Request-ID"); self.send_header("Access-Control-Allow-Private-Network", "true"); self.send_header("Access-Control-Max-Age", "600"); self.end_headers()

    def do_GET(self) -> None:
        if self.path == "/health": self.send_json(200, {"ok": True, "runtime": "MLX", "model": str(MODEL)}); return
        if self.path.startswith("/jobs/"):
            job_id = self.path.split("/", 2)[-1]
            with _jobs_lock:
                job = dict(_jobs.get(job_id, {"status": "missing", "message": "job not found"}))
            self.send_json(200 if job.get("status") != "missing" else 404, job); return
        self.send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path not in {"/analyze", "/analyze-upload"}: self.send_json(404, {"error": "not found"}); return
        request_id = self.headers.get("X-Request-ID") or uuid.uuid4().hex[:12]
        self._request_id = request_id
        started = time.perf_counter()
        logger.info("request_start id=%s method=POST path=%s content_length=%s", request_id, self.path, self.headers.get("Content-Length", "0"))
        try:
            length = int(self.headers.get("Content-Length", "0")); payload = json.loads(self.rfile.read(length))
            if self.path == "/analyze-upload":
                name = Path(str(payload.get("name", "upload.txt"))).name
                suffix = Path(name).suffix.lower()
                if suffix not in {".txt", ".md", ".eml", ".docx", ".pdf"}: raise ValueError("unsupported file type")
                raw = base64.b64decode(str(payload["data"]), validate=True)
                job_id = request_id
                with _jobs_lock:
                    _jobs[job_id] = {"status": "queued", "phase": "queued", "progress": 0, "name": name, "message": "已排队"}
                threading.Thread(target=run_job, args=(job_id, name, raw, suffix), daemon=True).start()
                self.send_json(202, {"job_id": job_id, "status": "queued", "name": name, "message": "任务已创建"})
            else:
                path = Path(str(payload["path"])).expanduser().resolve()
                if not path.is_file(): raise ValueError("file not found")
                self.send_json(200, analyze(path))
        except BrokenPipeError:
            logger.warning("request_client_disconnected id=%s", request_id)
        except Exception as exc:
            logger.error("request_error id=%s type=%s error=%s\n%s", request_id, type(exc).__name__, exc, traceback.format_exc())
            self.send_json(400, {"error": str(exc)})
        finally:
            logger.info("request_done id=%s elapsed_ms=%d", request_id, round((time.perf_counter() - started) * 1000))

    def log_message(self, *_args) -> None: return


def main() -> None:
    logger.info("service_start host=%s port=%d model=%s log_file=%s", HOST, PORT, MODEL, LOG_FILE)
    print(f"LegalRedaction local API: http://{HOST}:{PORT} (log: {LOG_FILE})")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__": main()
