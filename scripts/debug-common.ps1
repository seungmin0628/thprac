$ErrorActionPreference = 'Stop'
$script:RepoRoot = Split-Path $PSScriptRoot -Parent
$script:DebugRoot = Join-Path $script:RepoRoot '.debug'
function Write-DebugJson($Path, $Value) {
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Value -Depth 12), [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $Path) {
        for ($attempt = 0; ; $attempt++) {
            try { [IO.File]::Replace($temp, $Path, [NullString]::Value); break }
            catch [IO.IOException] {
                if ($attempt -ge 20) { throw }
                Start-Sleep -Milliseconds 50
            }
        }
    }
    else { [IO.File]::Move($temp, $Path) }
}
function Read-DebugJson($Path) {
    for ($attempt = 0; ; $attempt++) {
        $reader = $null
        try {
            $stream = [IO.File]::Open($Path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $reader = [IO.StreamReader]::new($stream)
            return ($reader.ReadToEnd() | ConvertFrom-Json)
        } catch [IO.IOException] {
            if ($attempt -ge 20) { throw }
            Start-Sleep -Milliseconds 50
        } finally { if ($reader) { $reader.Dispose() } }
    }
}
function Get-OwnedProcess($Record) {
    if (!$Record -or !$Record.pid -or !$Record.startedUtc) { return $null }
    $process = Get-Process -Id $Record.pid -ErrorAction SilentlyContinue
    if (!$process) { return $null }
    try {
        # Retain the handle before checking identity to prevent PID reuse races.
        $null = $process.Handle
        if ($process.StartTime.ToUniversalTime().Ticks -eq ([DateTime]$Record.startedUtc).ToUniversalTime().Ticks -and $process.Path -eq $Record.path) { return $process }
    } catch { }
    $process.Dispose()
    return $null
}
function Get-ProcessRecord($Process, $Path) {
    $null = $Process.Handle
    [pscustomobject]@{ pid=$Process.Id; path=$Path; startedUtc=$Process.StartTime.ToUniversalTime().ToString('o'); state='running'; exitCode=$null }
}
function Update-ProcessRecord($Process, $Record) {
    if (!$Process) { return }
    $Process.Refresh()
    if ($Process.HasExited) { $Record.state = 'exited'; $Record.exitCode = $Process.ExitCode }
    else { $Record.state = 'running' }
}
function Stop-OwnedProcess($Process) {
    if ($Process -and !$Process.HasExited) {
        # Only this retained handle; never a name or process tree.
        $Process.Kill()
        $Process.WaitForExit()
    }
}
function Get-SessionDirectory {
    $pointer = Join-Path $script:DebugRoot 'session.json'
    if (!(Test-Path -LiteralPath $pointer)) { return $null }
    $id = (Read-DebugJson $pointer).id
    if ($id -notmatch '^[0-9a-f]{32}$') { throw 'Invalid session ID in .debug\session.json.' }
    Join-Path $script:DebugRoot "sessions\$id"
}
