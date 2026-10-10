$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Run = Join-Path $Root ".run"
foreach ($Name in @("app","ocr","has")) {
    $PidFile = Join-Path $Run "$Name.pid"
    if (Test-Path $PidFile) {
        $ProcessId = [int](Get-Content $PidFile -Raw)
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
        Remove-Item $PidFile -Force
    }
}
Write-Host "PrivacyGuard 已停止。"
