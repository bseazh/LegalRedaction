#!/bin/zsh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_FILE="$ROOT_DIR/.run/runtime.env"
REPORT="$ROOT_DIR/logs/last-check.json"
APP_PYTHON="$ROOT_DIR/backend/.venv-mac/bin/python"
[[ -f "$RUNTIME_FILE" ]] || { print -u2 "没有找到启动记录，请先双击 Launch-PrivacyGuard.command。"; exit 2; }
source "$RUNTIME_FILE"
mkdir -p "$ROOT_DIR/logs"

health_json="$(curl -fsS --max-time 30 "$HEALTH_URL" 2>/dev/null || true)"
services_json="$(curl -fsS --max-time 30 "$SERVICES_URL" 2>/dev/null || true)"
if [[ -z "$health_json" || -z "$services_json" ]]; then
  print -u2 "检测失败：后端或服务状态接口无法访问。"
  print -u2 "日志：$ROOT_DIR/logs"
  exit 2
fi

"$APP_PYTHON" -c '
import json, sys, datetime
services=json.loads(sys.argv[1])
has=bool(services["services"]["has_ner"]["detail"].get("reachable"))
ocr=bool(services["services"]["paddle_ocr"]["detail"].get("reachable"))
ready=bool(services["services"]["paddle_ocr"]["detail"].get("ready"))
result={"checked_at":datetime.datetime.now().astimezone().isoformat(),"app_url":sys.argv[2],"backend":"online","has":"online" if has else "offline","ocr":"online" if ocr else "offline","ocr_ready":ready,"result":"passed" if has and ocr and ready else "failed"}
open(sys.argv[3],"w",encoding="utf-8").write(json.dumps(result,ensure_ascii=False,indent=2))
print("----------------------------------------")
print("PrivacyGuard 检测结果："+result["result"])
print("后端：online")
print("HaS："+result["has"])
print("OCR：%s，ready=%s"%(result["ocr"],str(ready).lower()))
print("应用："+sys.argv[2])
print("报告："+sys.argv[3])
print("----------------------------------------")
sys.exit(0 if result["result"]=="passed" else 2)
' "$services_json" "$APP_URL" "$REPORT"
