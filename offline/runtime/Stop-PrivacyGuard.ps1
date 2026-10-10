param([switch]$Quiet)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Run = Join-Path $Root ".run"
$Warnings = 0

function Test-ProcessIdentity($Record, $ProcessInfo) {
    if (-not $ProcessInfo -or -not $ProcessInfo.ExecutablePath) { return $false }
    $Expected = [IO.Path]::GetFullPath([string]$Record.executable)
    $Actual = [IO.Path]::GetFullPath([string]$ProcessInfo.ExecutablePath)
    if (-not $Expected.Equals($Actual, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    $CommandLine = [string]$ProcessInfo.CommandLine
    foreach ($Marker in @($Record.command_markers)) {
        if ($CommandLine.IndexOf([string]$Marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }
    try {
        $ExpectedStart = [DateTime]::Parse([string]$Record.started_at).ToUniversalTime()
        $ActualStart = ([DateTime]$ProcessInfo.CreationDate).ToUniversalTime()
        if ([Math]::Abs(($ExpectedStart - $ActualStart).TotalSeconds) -gt 10) { return $false }
    } catch { return $false }
    return $true
}

foreach ($Name in @("app","ocr","has")) {
    $RecordFile = Join-Path $Run "$Name.process.json"
    $PidFile = Join-Path $Run "$Name.pid"
    if (-not (Test-Path $RecordFile)) {
        if (Test-Path $PidFile) {
            $Warnings++
            Write-Warning "忽略缺少身份记录的旧 PID 文件：$PidFile；不会结束无法确认身份的进程。"
            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        }
        continue
    }
    try {
        $Record = Get-Content $RecordFile -Raw | ConvertFrom-Json
        $ProcessInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$Record.pid)" -ErrorAction SilentlyContinue
        if (Test-ProcessIdentity $Record $ProcessInfo) {
            Stop-Process -Id ([int]$Record.pid) -Force -ErrorAction Stop
        } elseif ($ProcessInfo) {
            $Warnings++
            Write-Warning "PID $($Record.pid) 的身份与 $Name 记录不一致，已跳过，避免结束其他程序。"
        }
    } catch {
        $Warnings++
        Write-Warning "停止 $Name 时未能验证或结束进程：$($_.Exception.Message)"
    } finally {
        Remove-Item $RecordFile,$PidFile -Force -ErrorAction SilentlyContinue
    }
}
if (-not $Quiet) {
    if ($Warnings -eq 0) { Write-Host "PrivacyGuard 已安全停止。其他软件的进程不会被结束。" }
    else { Write-Host "PrivacyGuard 停止流程完成，但有 $Warnings 个安全警告；请查看上方信息。" }
}
