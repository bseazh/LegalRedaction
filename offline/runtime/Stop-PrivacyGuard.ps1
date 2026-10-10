param([switch]$Quiet)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Run = Join-Path $Root ".run"
$Warnings = 0

function Mark-RecordStale([string]$RecordFile, $Record, [string]$Reason) {
    $Record | Add-Member -NotePropertyName status -NotePropertyValue "stale" -Force
    $Record | Add-Member -NotePropertyName stale_reason -NotePropertyValue $Reason -Force
    $Record | Add-Member -NotePropertyName checked_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString("o")) -Force
    $Record | ConvertTo-Json | Set-Content $RecordFile -Encoding UTF8
}

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
    $RemoveRecord = $false
    $Record = $null
    try {
        $Record = Get-Content $RecordFile -Raw | ConvertFrom-Json
        $ProcessInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$Record.pid)" -ErrorAction SilentlyContinue
        if (-not $ProcessInfo) {
            $RemoveRecord = $true
        } elseif (Test-ProcessIdentity $Record $ProcessInfo) {
            Stop-Process -Id ([int]$Record.pid) -Force -ErrorAction Stop
            $Deadline = (Get-Date).AddSeconds(10)
            while ((Get-Process -Id ([int]$Record.pid) -ErrorAction SilentlyContinue) -and (Get-Date) -lt $Deadline) {
                Start-Sleep -Milliseconds 200
            }
            if (Get-Process -Id ([int]$Record.pid) -ErrorAction SilentlyContinue) {
                throw "进程在停止命令后仍然存在"
            }
            $RemoveRecord = $true
        } else {
            $Warnings++
            $Reason = "PID $($Record.pid) 的身份与 $Name 记录不一致，已跳过，避免结束其他程序。"
            Write-Warning $Reason
            Mark-RecordStale $RecordFile $Record $Reason
        }
    } catch {
        $Warnings++
        $Reason = "停止 $Name 时未能验证或结束进程：$($_.Exception.Message)"
        Write-Warning $Reason
        if ($Record) { Mark-RecordStale $RecordFile $Record $Reason }
    } finally {
        if ($RemoveRecord) { Remove-Item $RecordFile,$PidFile -Force -ErrorAction SilentlyContinue }
    }
}
if (-not $Quiet) {
    if ($Warnings -eq 0) { Write-Host "PrivacyGuard 已安全停止。其他软件的进程不会被结束。" }
    else { Write-Host "PrivacyGuard 停止流程完成，但有 $Warnings 个安全警告；请查看上方信息。" }
}
