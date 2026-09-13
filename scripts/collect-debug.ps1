[CmdletBinding()]
param([string]$SessionDirectory)
. "$PSScriptRoot\debug-common.ps1"
try {
    if (!$SessionDirectory) { $SessionDirectory = Get-SessionDirectory }
    if (!$SessionDirectory) { Write-Output '{"phase":"no-session"}'; exit 0 }
    $state = Read-DebugJson (Join-Path $SessionDirectory 'state.json')
    $dest = Join-Path $SessionDirectory ("diagnostics\" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $notes = [Collections.Generic.List[string]]::new()
    $processes = foreach ($record in @($state.worker, $state.thprac, $state.game, $state.loader)) {
        if (!$record) { continue }
        $live = Get-OwnedProcess $record
        [pscustomobject]@{
            pid=$record.pid; path=$record.path; startedUtc=$record.startedUtc
            recordedState=$record.state; alive=[bool]$live; exitCode=$record.exitCode
            responding=$(if ($live) { $live.Responding } else { $null })
            windowTitle=$(if ($live) { $live.MainWindowTitle } else { $null })
        }
        if ($live) { $live.Dispose() }
    }
    Write-DebugJson (Join-Path $dest 'processes.json') @($processes)
    Write-DebugJson (Join-Path $dest 'session.json') $state
    $targetConfig = Join-Path $SessionDirectory 'thcrap-target.js'
    if (Test-Path -LiteralPath $targetConfig) { Copy-Item -LiteralPath $targetConfig -Destination $dest }
    Copy-Item -Path "$SessionDirectory\worker.*.log" -Destination $dest -ErrorAction SilentlyContinue
    $sources = @((Join-Path (Split-Path $state.thpracPath -Parent) '.thprac_data\logs'))
    if ($state.thcrap) { $sources += Join-Path $state.thcrap.workingDirectory 'logs' }
    if ($state.gamePath) {
        $sources += Join-Path (Split-Path $state.gamePath -Parent) '.thprac_data\logs'
        if ($env:APPDATA) { $sources += Join-Path $env:APPDATA 'thprac\logs' }
    }
    $index = 0
    foreach ($source in ($sources | Select-Object -Unique)) {
        $index++
        try {
            if (Test-Path -LiteralPath $source) {
                $logDest = Join-Path $dest "logs-$index"
                New-Item -ItemType Directory -Path $logDest | Out-Null
                Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Name -match '^(thprac.*log|thcrap_log).*\.txt$' } |
                    Where-Object { $_.LastWriteTimeUtc -ge ([DateTime]$state.startedUtc).ToUniversalTime() } |
                    Copy-Item -Destination $logDest
            }
            $notes.Add("Log source $index : $source (shared sources may contain other thprac activity)")
        } catch { $notes.Add("Log collection failed: $($_.Exception.Message)") }
    }
    try {
        $events = @(Get-WinEvent -FilterHashtable @{
            LogName='Application'; Id=@(1000,1001,1002); StartTime=([DateTime]$state.startedUtc).ToLocalTime()
        } -ErrorAction Stop | Where-Object {
            $message = $_.Message
            ($message -and $message.IndexOf('thprac.exe', [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
            ($state.gamePath -and $message -and $message.IndexOf([IO.Path]::GetFileName($state.gamePath), [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
            ($state.thcrap -and $message -and $message.IndexOf([IO.Path]::GetFileName($state.thcrap.loader), [StringComparison]::OrdinalIgnoreCase) -ge 0)
        } | Select-Object TimeCreated, Id, ProviderName, Message)
        Write-DebugJson (Join-Path $dest 'application-events.json') $events
        $notes.Add('Application events are time/name-filtered candidates, not proven crash attribution.')
    } catch { $notes.Add("Application events unavailable or none found: $($_.Exception.Message)") }
    $dumps = @()
    if ($env:LOCALAPPDATA) {
        $dumpRoot = Join-Path $env:LOCALAPPDATA 'CrashDumps'
        if (Test-Path -LiteralPath $dumpRoot) {
            $dumps = @(Get-ChildItem -LiteralPath $dumpRoot -Filter '*.dmp' -File | Where-Object {
                $_.LastWriteTimeUtc -ge ([DateTime]$state.startedUtc).ToUniversalTime() -and
                ($_.Name -like 'thprac.exe.*.dmp' -or
                    ($state.gamePath -and $_.Name.StartsWith([IO.Path]::GetFileName($state.gamePath) + '.', [StringComparison]::OrdinalIgnoreCase)) -or
                    ($state.thcrap -and $_.Name.StartsWith([IO.Path]::GetFileName($state.thcrap.loader) + '.', [StringComparison]::OrdinalIgnoreCase)))
            } | Select-Object FullName, Length, LastWriteTimeUtc)
        }
    }
    Write-DebugJson (Join-Path $dest 'dump-paths.json') $dumps
    $files = @($state.thpracPath, ([IO.Path]::ChangeExtension($state.thpracPath, '.pdb')),
        (Join-Path $RepoRoot 'thprac\src\thprac\thprac_locale_def.cpp'), (Join-Path $RepoRoot 'thprac\src\thprac\thprac_locale_def.h'))
    if ($state.thcrap) { $files += @($state.thcrap.loader, $state.thcrap.config, $targetConfig) }
    $inventory = @(foreach ($file in $files) {
        if (Test-Path -LiteralPath $file) {
            $item = Get-Item -LiteralPath $file
            [pscustomobject]@{path=$file; length=$item.Length; modifiedUtc=$item.LastWriteTimeUtc; sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
        }
    })
    Write-DebugJson (Join-Path $dest 'artifacts.json') $inventory
    $notes.Add('No native minidump handler found. Existing default WER dump paths only; custom WER locations are not searched or configured.')
    $notes.Add('Exit codes require the session worker to retain process handles. Unavailable codes remain null.')
    $notes | Set-Content -LiteralPath (Join-Path $dest 'collection-notes.txt') -Encoding UTF8
    Write-Output $dest
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
