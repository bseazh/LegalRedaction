$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Logs = Join-Path $Root "logs"
$Run = Join-Path $Root ".run"
New-Item -ItemType Directory -Force -Path $Logs,$Run | Out-Null

$AppPython = Join-Path $Root "backend\.venv-win\Scripts\python.exe"
$OcrPython = Join-Path $Root "backend\.venv-ocr-win\Scripts\python.exe"
$Llama = Get-ChildItem (Join-Path $Root "runtime\llama") -Recurse -Filter "llama-server.exe" | Select-Object -First 1
$Model = Join-Path $Root "backend\models\has\has_4.0_0.6B.gguf"
if (-not (Test-Path $AppPython) -or -not (Test-Path $OcrPython) -or -not $Llama -or -not (Test-Path $Model)) {
    throw "运行环境不完整，请先执行 Install-Offline-Windows.ps1。"
}

$Has = Start-Process -PassThru -WindowStyle Hidden -FilePath $Llama.FullName -ArgumentList @("-m",$Model,"--host","127.0.0.1","--port","8080","-c","4096","--chat-template","chatml") -RedirectStandardOutput (Join-Path $Logs "has.log") -RedirectStandardError (Join-Path $Logs "has.err.log")
$Has.Id | Set-Content (Join-Path $Run "has.pid")

$env:OCR_DEVICE="cpu"
$env:OCR_VL_ENABLED="0"
$env:OCR_STRUCTURE_ENABLED="1"
$env:OCR_STRUCTURE_WARMUP="0"
$env:OCR_PORT="8082"
$env:PADDLE_PDX_CACHE_HOME=Join-Path $Root "backend\models\paddlex-cache"
$env:PADDLE_PDX_MODEL_SOURCE="modelscope"
$env:PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK="True"
$Ocr = Start-Process -PassThru -WindowStyle Hidden -FilePath $OcrPython -ArgumentList (Join-Path $Root "backend\scripts\ocr_server.py") -RedirectStandardOutput (Join-Path $Logs "ocr.log") -RedirectStandardError (Join-Path $Logs "ocr.err.log")
$Ocr.Id | Set-Content (Join-Path $Run "ocr.pid")

$env:AUTH_ENABLED="false"
$env:DEBUG="false"
$env:DATA_DIR=Join-Path $Root "backend\data"
$env:UPLOAD_DIR=Join-Path $Root "backend\uploads"
$env:OUTPUT_DIR=Join-Path $Root "backend\outputs"
$env:HAS_TEXT_RUNTIME="llamacpp"
$env:HAS_LLAMACPP_BASE_URL="http://127.0.0.1:8080/v1"
$env:HAS_NER_CONTEXT_TOKENS="4096"
$env:HAS_NER_MAX_TOKENS="1024"
$env:OCR_BASE_URL="http://127.0.0.1:8082"
$env:OCR_REQUIRE_GPU="false"
$App = Start-Process -PassThru -WindowStyle Hidden -WorkingDirectory $Root -FilePath $AppPython -ArgumentList @("-m","uvicorn","app.main:app","--app-dir",(Join-Path $Root "backend"),"--host","127.0.0.1","--port","8000") -RedirectStandardOutput (Join-Path $Logs "app.log") -RedirectStandardError (Join-Path $Logs "app.err.log")
$App.Id | Set-Content (Join-Path $Run "app.pid")

Write-Host "PrivacyGuard 已启动：http://127.0.0.1:8000"
Write-Host "服务状态：http://127.0.0.1:8000/health/services"
Start-Sleep -Seconds 3
Start-Process "http://127.0.0.1:8000"
