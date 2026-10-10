param(
    [int]$TimeoutSeconds = 30,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RuntimeFile = Join-Path $Root ".run\runtime.json"
$Logs = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $Logs | Out-Null
if (-not (Test-Path $RuntimeFile)) { throw "没有找到启动记录，请先双击 Launch-PrivacyGuard.cmd。" }
$Runtime = Get-Content $RuntimeFile -Raw | ConvertFrom-Json
$Result = [ordered]@{
    checked_at = (Get-Date).ToString("o")
    app_url = $Runtime.app_url
    backend = "offline"
    has = "offline"
    ocr = "offline"
    ocr_ready = $false
    result = "failed"
}
try {
    Invoke-RestMethod -Uri $Runtime.health_url -TimeoutSec $TimeoutSeconds | Out-Null
    $Result.backend = "online"
    $Services = Invoke-RestMethod -Uri $Runtime.services_url -TimeoutSec $TimeoutSeconds
    if ($Services.services.has_ner.detail.reachable) { $Result.has = "online" }
    if ($Services.services.paddle_ocr.detail.reachable) { $Result.ocr = "online" }
    $Result.ocr_ready = [bool]$Services.services.paddle_ocr.detail.ready
    if ($Result.backend -eq "online" -and $Result.has -eq "online" -and $Result.ocr -eq "online" -and $Result.ocr_ready) { $Result.result = "passed" }
} catch {
    $Result.error = $_.Exception.Message
}
$Result | ConvertTo-Json | Set-Content (Join-Path $Logs "last-check.json") -Encoding UTF8
if (-not $Quiet) {
    Write-Host "----------------------------------------"
    Write-Host "PrivacyGuard 检测结果：$($Result.result)"
    Write-Host "后端：$($Result.backend)"
    Write-Host "HaS：$($Result.has)"
    Write-Host "OCR：$($Result.ocr)，ready=$($Result.ocr_ready)"
    Write-Host "应用：$($Result.app_url)"
    Write-Host "报告：$(Join-Path $Logs 'last-check.json')"
    Write-Host "----------------------------------------"
}
if ($Result.result -ne "passed") { throw "PrivacyGuard 检测未通过，请查看 $Logs\last-check.json 和服务日志。" }
