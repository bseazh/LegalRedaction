param(
    [switch]$NoBrowser,
    [int]$StartupTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Logs = Join-Path $Root "logs"
$Run = Join-Path $Root ".run"
New-Item -ItemType Directory -Force -Path $Logs,$Run | Out-Null

$AppPython = Join-Path $Root "backend\.venv-win\Scripts\python.exe"
$OcrPython = Join-Path $Root "backend\.venv-ocr-win\Scripts\python.exe"
$Llama = Get-ChildItem (Join-Path $Root "runtime\llama") -Recurse -Filter "llama-server.exe" | Select-Object -First 1
$Model = Join-Path $Root "backend\models\has\has_4.0_0.6B.gguf"
if (-not (Test-Path $AppPython) -or -not (Test-Path $OcrPython) -or -not $Llama -or -not (Test-Path $Model)) {
    throw "运行环境不完整，请先双击 Install-PrivacyGuard.cmd 完成安装。"
}

function Test-PortAvailable([int]$Port) {
    return -not (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}
function Select-Port([int[]]$Candidates, [string]$ServiceName) {
    foreach ($Port in $Candidates) {
        if (Test-PortAvailable $Port) { return $Port }
    }
    throw "$ServiceName 没有可用端口。已检查：$($Candidates -join ', ')"
}
function Wait-Json([string]$Uri, [int]$TimeoutSeconds) {
    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try { return Invoke-RestMethod -Uri $Uri -TimeoutSec 10 }
        catch { Start-Sleep -Seconds 2 }
    } while ((Get-Date) -lt $Deadline)
    return $null
}
function Save-ProcessRecord([string]$Name, $Process, [string]$ExpectedExecutable, [string[]]$CommandMarkers) {
    $Process.Refresh()
    [ordered]@{
        pid = $Process.Id
        executable = [IO.Path]::GetFullPath($ExpectedExecutable)
        command_markers = $CommandMarkers
        started_at = $Process.StartTime.ToUniversalTime().ToString("o")
    } | ConvertTo-Json | Set-Content (Join-Path $Run "$Name.process.json") -Encoding UTF8
    $Process.Id | Set-Content (Join-Path $Run "$Name.pid")
}

# Restart only processes previously launched by this package. Never terminate an unrelated port owner.
$StopScript = Join-Path $Root "Stop-PrivacyGuard.ps1"
if (Test-Path $StopScript) { & $StopScript -Quiet }
$StaleRecords = @(Get-ChildItem $Run -Filter "*.process.json" -ErrorAction SilentlyContinue | Where-Object {
    try { (Get-Content $_.FullName -Raw | ConvertFrom-Json).status -eq "stale" } catch { $false }
})
if ($StaleRecords.Count -gt 0) {
    throw "检测到未解决的 stale 进程记录：$($StaleRecords.Name -join ', ')。为避免启动重复服务，请先查看警告并确认对应进程。"
}

$BackendPort = Select-Port @(8000,18000,28000,38000) "应用"
$HasPort = Select-Port @(8080,18080,28080,38080) "HaS"
$OcrPort = Select-Port @(8082,18082,28082,38082) "OCR"

Write-Host "正在启动 PrivacyGuard..."
Write-Host "应用端口：$BackendPort；HaS：$HasPort；OCR：$OcrPort"

try {
$Has = Start-Process -PassThru -WindowStyle Hidden -FilePath $Llama.FullName -ArgumentList @("-m",$Model,"--host","127.0.0.1","--port","$HasPort","-c","4096","--chat-template","chatml") -RedirectStandardOutput (Join-Path $Logs "has.log") -RedirectStandardError (Join-Path $Logs "has.err.log")
Save-ProcessRecord "has" $Has $Llama.FullName @($Model,"--port $HasPort")

$env:OCR_DEVICE="cpu"
$env:OCR_VL_ENABLED="0"
$env:OCR_STRUCTURE_ENABLED="1"
$env:OCR_STRUCTURE_WARMUP="0"
$env:OCR_PORT="$OcrPort"
$env:PADDLE_PDX_CACHE_HOME=Join-Path $Root "backend\models\paddlex-cache"
$env:PADDLE_PDX_MODEL_SOURCE="modelscope"
$env:PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK="True"
$OcrScript = Join-Path $Root "backend\scripts\ocr_server.py"
$Ocr = Start-Process -PassThru -WindowStyle Hidden -FilePath $OcrPython -ArgumentList $OcrScript -RedirectStandardOutput (Join-Path $Logs "ocr.log") -RedirectStandardError (Join-Path $Logs "ocr.err.log")
Save-ProcessRecord "ocr" $Ocr $OcrPython @($OcrScript)

$env:AUTH_ENABLED="false"
$env:DEBUG="false"
$env:DATA_DIR=Join-Path $Root "backend\data"
$env:UPLOAD_DIR=Join-Path $Root "backend\uploads"
$env:OUTPUT_DIR=Join-Path $Root "backend\outputs"
$env:HAS_TEXT_RUNTIME="llamacpp"
$env:HAS_LLAMACPP_BASE_URL="http://127.0.0.1:$HasPort/v1"
$env:HAS_NER_CONTEXT_TOKENS="4096"
$env:HAS_NER_MAX_TOKENS="1024"
$env:OCR_BASE_URL="http://127.0.0.1:$OcrPort"
$env:OCR_REQUIRE_GPU="false"
$App = Start-Process -PassThru -WindowStyle Hidden -WorkingDirectory $Root -FilePath $AppPython -ArgumentList @("-m","uvicorn","app.main:app","--app-dir",(Join-Path $Root "backend"),"--host","127.0.0.1","--port","$BackendPort") -RedirectStandardOutput (Join-Path $Logs "app.log") -RedirectStandardError (Join-Path $Logs "app.err.log")
Save-ProcessRecord "app" $App $AppPython @("app.main:app",(Join-Path $Root "backend"))

$Runtime = [ordered]@{
    platform = "windows"
    started_at = (Get-Date).ToString("o")
    app_url = "http://127.0.0.1:$BackendPort"
    health_url = "http://127.0.0.1:$BackendPort/health"
    services_url = "http://127.0.0.1:$BackendPort/health/services"
    backend_port = $BackendPort
    has_port = $HasPort
    ocr_port = $OcrPort
}
$Runtime | ConvertTo-Json | Set-Content (Join-Path $Run "runtime.json") -Encoding UTF8

Write-Host "等待后端和模型服务就绪（首次启动可能需要数分钟）..."
$Health = Wait-Json $Runtime.health_url ([Math]::Min($StartupTimeoutSeconds, 120))
if (-not $Health) { throw "后端未能启动。请双击 Check-PrivacyGuard.cmd；日志位于 $Logs" }
$Services = Wait-Json $Runtime.services_url $StartupTimeoutSeconds
if (-not $Services) { throw "服务状态接口未响应。请双击 Check-PrivacyGuard.cmd；日志位于 $Logs" }
$Deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
$Passed = $false
do {
    try {
        & (Join-Path $Root "Test-PrivacyGuard.ps1") -Quiet
        $Passed = $true
        break
    } catch {}
    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $Deadline)
if (-not $Passed) { throw "模型服务在等待时间内未就绪。请双击 Check-PrivacyGuard.cmd；日志位于 $Logs" }
& (Join-Path $Root "Test-PrivacyGuard.ps1")
Write-Host "应用地址：$($Runtime.app_url)"
Write-Host "以后可直接双击 Launch-PrivacyGuard.cmd 启动。"
if (-not $NoBrowser) { Start-Process $Runtime.app_url }
} catch {
    $Failure = $_
    Write-Host "启动失败，正在安全清理本次启动的 PrivacyGuard 进程。日志会保留在 $Logs" -ForegroundColor Red
    try { & $StopScript -Quiet } catch {}
    throw $Failure
}
