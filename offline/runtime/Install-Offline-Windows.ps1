param(
    [string]$PackageDirectory = "",
    [switch]$InstallPython
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $PackageDirectory) { $PackageDirectory = Split-Path -Parent $Root }
if (-not [Environment]::Is64BitOperatingSystem) { throw "此离线包仅支持 Windows x64。" }

$Version = (Get-Content (Join-Path $Root "OFFLINE_VERSION") -Raw).Trim()
$HasName = "PrivacyGuard-standard-model-has-$Version.tar.gz"
$OcrName = "PrivacyGuard-standard-model-paddleocr-$Version.tar.gz"
$Manifest = Join-Path $Root "COMPONENTS.sha256"

function Find-Component([string]$Name) {
    $Candidates = @((Join-Path $PackageDirectory $Name), (Join-Path (Join-Path $Root "packages") $Name))
    foreach ($Path in $Candidates) { if (Test-Path $Path) { return $Path } }
    throw "缺少模型包：$Name"
}
function Verify-Component([string]$Path) {
    $Name = Split-Path -Leaf $Path
    $Line = Get-Content $Manifest | Where-Object { $_ -match "\s+$([regex]::Escape($Name))$" } | Select-Object -First 1
    if (-not $Line) { throw "校验清单中没有 $Name" }
    $Expected = ($Line -split '\s+')[0].ToLowerInvariant()
    $Actual = (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
    if ($Expected -ne $Actual) { throw "SHA-256 校验失败：$Path" }
}

foreach ($Name in @($HasName, $OcrName)) {
    $Archive = Find-Component $Name
    Write-Host "校验 $Name ..."
    Verify-Component $Archive
    tar -xzf $Archive -C $Root
}

$Python = $null
$Candidates = @(
    (Join-Path $env:LocalAppData "Programs\Python\Python311\python.exe"),
    "C:\Program Files\Python311\python.exe"
)
foreach ($Candidate in $Candidates) { if (Test-Path $Candidate) { $Python = $Candidate; break } }
if (-not $Python) {
    try { $Python = (& py -3.11 -c "import sys; print(sys.executable)" 2>$null).Trim() } catch {}
}
if (-not $Python -and $InstallPython) {
    $Installer = Join-Path $Root "prerequisites\python-3.11.9-amd64.exe"
    Start-Process -Wait -FilePath $Installer -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0"
    $Python = Join-Path $env:LocalAppData "Programs\Python\Python311\python.exe"
}
if (-not $Python -or -not (Test-Path $Python)) {
    throw "未找到 Python 3.11。请运行 prerequisites\python-3.11.9-amd64.exe，或重新执行：.\Install-Offline-Windows.ps1 -InstallPython"
}

$AppVenv = Join-Path $Root "backend\.venv-win"
$OcrVenv = Join-Path $Root "backend\.venv-ocr-win"
Remove-Item -Recurse -Force $AppVenv,$OcrVenv -ErrorAction SilentlyContinue
& $Python -m venv $AppVenv
& $Python -m venv $OcrVenv
& (Join-Path $AppVenv "Scripts\python.exe") -m pip install --no-index --find-links (Join-Path $Root "wheelhouse\app") -r (Join-Path $Root "offline\requirements\windows-app.txt")
& (Join-Path $OcrVenv "Scripts\python.exe") -m pip install --no-index --find-links (Join-Path $Root "wheelhouse\ocr") -r (Join-Path $Root "offline\requirements\windows-ocr.txt")

New-Item -ItemType Directory -Force -Path (Join-Path $Root "backend\data"),(Join-Path $Root "backend\uploads"),(Join-Path $Root "backend\outputs"),(Join-Path $Root "logs") | Out-Null
& (Join-Path $AppVenv "Scripts\python.exe") -c "import fastapi, fitz, docx; print('应用环境正常')"
& (Join-Path $OcrVenv "Scripts\python.exe") -c "import paddle, paddleocr; print('OCR 环境正常')"
Write-Host "离线安装完成。运行 .\Start-PrivacyGuard.ps1 启动。"
