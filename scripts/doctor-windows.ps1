param(
    [ValidateSet("basic", "standard", "full")]
    [string]$Profile = "standard"
)

$ErrorActionPreference = "SilentlyContinue"
$Failures = 0
$Warnings = 0
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Ok($Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Warn($Message) { $script:Warnings++; Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Fail($Message) { $script:Failures++; Write-Host "[FAIL] $Message" -ForegroundColor Red }
function Has-Command($Name) { return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

Write-Host "PrivacyGuard Windows installation doctor"
Write-Host "Profile: $Profile"
Write-Host "----------------------------------------"

$Os = Get-CimInstance Win32_OperatingSystem
if ($Os) { Ok "Windows $($Os.Caption) $($Os.Version)" } else { Fail "Unable to read Windows version" }

$RamGb = [math]::Floor(($Os.TotalVisibleMemorySize * 1KB) / 1GB)
$MinRam = if ($Profile -eq "full") { 24 } elseif ($Profile -eq "standard") { 16 } else { 8 }
if ($RamGb -ge $MinRam) { Ok "Memory: ${RamGb}GB" } else { Fail "Memory: ${RamGb}GB; $Profile recommends ${MinRam}GB" }

$Drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($Root).TrimEnd(':\'))
$FreeGb = [math]::Floor($Drive.Free / 1GB)
$MinDisk = if ($Profile -eq "full") { 35 } elseif ($Profile -eq "standard") { 20 } else { 10 }
if ($FreeGb -ge $MinDisk) { Ok "Free disk: ${FreeGb}GB" } else { Fail "Free disk: ${FreeGb}GB; $Profile requires ${MinDisk}GB" }

foreach ($Command in @("git", "node", "npm", "python")) {
    if (Has-Command $Command) { Ok "$Command is installed" } else { Fail "$Command is missing" }
}

if ($Profile -ne "basic") {
    if (Has-Command "wsl") {
        $WslStatus = & wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) { Ok "WSL2 is available" } else { Fail "WSL is installed but not ready" }
    } else { Fail "WSL2 is required for $Profile" }
}

if ($Profile -eq "full") {
    if (Has-Command "nvidia-smi") { Ok "NVIDIA driver is visible" } else { Fail "Full profile requires a supported NVIDIA GPU/driver" }
    if (Has-Command "wsl") {
        & wsl nvidia-smi *> $null
        if ($LASTEXITCODE -eq 0) { Ok "NVIDIA GPU is visible inside WSL" } else { Fail "WSL cannot access the NVIDIA GPU" }
    }
}

foreach ($Port in @(3000, 8000, 8080, 8082, 8090)) {
    $Listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Listener) { Warn "Port $Port is already listening (PID $($Listener.OwningProcess)); ignore only if it is this project" } else { Ok "Port $Port is available" }
}

$HasModel = Join-Path $Root "backend\models\has\HaS_Text_0209_0.6B"
$LocateModel = Join-Path $Root "backend\models\locateanything\LocateAnything-3B-HF"
if ($Profile -ne "basic") {
    if (Test-Path $HasModel) { Ok "HaS model directory exists" } else { Warn "HaS model directory is not installed" }
}
if ($Profile -eq "full") {
    if (Test-Path $LocateModel) { Ok "LocateAnything model directory exists" } else { Warn "LocateAnything model directory is not installed" }
}

Write-Host "----------------------------------------"
Write-Host "Result: $Failures failure(s), $Warnings warning(s)"
if ($Failures -gt 0) {
    Write-Host "Not ready for $Profile. Resolve [FAIL] items first." -ForegroundColor Red
    exit 2
}
Write-Host "Hardware and base tools meet $Profile. [WARN] items still require installation or confirmation." -ForegroundColor Green
Write-Host "Next: docs\installation\windows.md"
