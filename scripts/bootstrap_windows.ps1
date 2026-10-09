$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

function Require-Command($Name, $InstallHint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "未找到 $Name。请先执行：$InstallHint，然后重新打开 PowerShell。"
    }
}

Require-Command python "winget install Python.Python.3.12"
Require-Command node "winget install OpenJS.NodeJS.LTS"
Require-Command pdftotext "winget install oschwartz10612.Poppler"

python -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r service\requirements-windows.txt
npm --prefix app ci
Write-Host "安装完成。运行：powershell -ExecutionPolicy Bypass -File scripts\start_windows.ps1"
