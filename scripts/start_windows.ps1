$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir
$env:PRIVACYGUARD_NER_BACKEND = "rules"

$Api = Start-Process -FilePath ".\.venv\Scripts\python.exe" -ArgumentList "-m", "service.local_api" -PassThru -NoNewWindow
try {
    npm --prefix app run dev
} finally {
    Stop-Process -Id $Api.Id -ErrorAction SilentlyContinue
}
