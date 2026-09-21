[CmdletBinding()]
param(
    [Parameter(Position=0)][ValidateSet('start','status','collect','stop')][string]$Action = 'status',
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')][string]$Game,
    [string]$GamePath,
    [switch]$LauncherOnly,
    [ValidateSet('Debug','Release')][string]$Configuration = 'Debug'
)
. "$PSScriptRoot\debug-common.ps1"
$lock = $null
try {
    New-Item -ItemType Directory -Force -Path $DebugRoot | Out-Null
    try { $lock = [IO.File]::Open((Join-Path $DebugRoot 'control.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Another session command is running; retry when it finishes.' }
    $dir = Get-SessionDirectory
    $state = $null
    if ($dir) { $state = Read-DebugJson (Join-Path $dir 'state.json') }
    if ($Action -eq 'start') {
        $thcrap = $null
        if ($state) {
            foreach ($record in @($state.worker, $state.thprac, $state.game, $state.loader)) {
                $live = Get-OwnedProcess $record
                if ($live) { $live.Dispose(); throw 'The previous session still has a live process. Run debug-session.ps1 stop first.' }
            }
        }
        if ($LauncherOnly -and ($Game -or $GamePath)) { throw 'Use -LauncherOnly without -Game or -GamePath.' }
        if (!$LauncherOnly) {
            if (!$Game) { throw 'Specify -Game TH18 (with a configured executable) or -LauncherOnly.' }
            if ($Game -ieq 'TH6') { $Game = 'TH06' }
            if (!$GamePath) { $GamePath = [Environment]::GetEnvironmentVariable("THPRAC_TEST_$($Game.ToUpperInvariant())") }
            $localConfig = Join-Path $RepoRoot 'debug.local.json'
            if (Test-Path -LiteralPath $localConfig) {
                $config = Read-DebugJson $localConfig
                $entry = $config.games.PSObject.Properties[$Game]
                if ($entry) {
                    if ($entry.Value -is [string]) {
                        if (!$GamePath) { $GamePath = $entry.Value }
                    } else {
                        if (!$GamePath) { $GamePath = [string]$entry.Value.path }
                        $thcrap = $entry.Value.thcrap
                    }
                }
            }
            if (!$GamePath -or ![IO.Path]::IsPathRooted($GamePath) -or !(Test-Path -LiteralPath $GamePath -PathType Leaf)) {
                throw "No valid absolute game executable path for $Game. Set THPRAC_TEST_$($Game.ToUpperInvariant()), debug.local.json, or -GamePath."
            }
            $GamePath = (Get-Item -LiteralPath $GamePath).FullName
            if ([IO.Path]::GetExtension($GamePath) -ine '.exe') { throw 'The game path must refer to an .exe file.' }
            if ($Game -ieq 'TH06' -and !$thcrap) { throw 'TH06 requires a thcrap entry in debug.local.json. See debug.example.json.' }
            if ($thcrap) {
                foreach ($field in @('loader', 'config')) {
                    $value = [string]$thcrap.$field
                    if (!$value -or ![IO.Path]::IsPathFullyQualified($value) -or !(Test-Path -LiteralPath $value -PathType Leaf)) {
                        throw "thcrap.$field must be an existing absolute file path."
                    }
                }
                if ([IO.Path]::GetExtension($thcrap.loader) -ine '.exe') { throw 'thcrap.loader must be an executable.' }
                if ([IO.Path]::GetExtension($thcrap.config) -ine '.js') { throw 'thcrap.config must be a run configuration ending in .js.' }
                # Prefer the real loader over the root bootstrap (which may install a runtime).
                $loader = (Get-Item -LiteralPath $thcrap.loader).FullName
                $loaderDir = Split-Path $loader -Parent
                $innerLoader = Join-Path $loaderDir 'bin\thcrap_loader.exe'
                if ((Split-Path $loader -Leaf) -ieq 'thcrap_loader.exe' -and (Test-Path -LiteralPath $innerLoader)) {
                    $loader = $innerLoader
                }
                $workingDirectory = [string]$thcrap.workingDirectory
                if (!$workingDirectory) {
                    $workingDirectory = Split-Path $loader -Parent
                    if ((Split-Path $workingDirectory -Leaf) -ieq 'bin') { $workingDirectory = Split-Path $workingDirectory -Parent }
                }
                if (![IO.Path]::IsPathFullyQualified($workingDirectory) -or !(Test-Path -LiteralPath $workingDirectory -PathType Container)) {
                    throw 'thcrap.workingDirectory must be an existing absolute directory.'
                }
                $timeout = 60
                if ($thcrap.timeoutSeconds) { $timeout = [int]$thcrap.timeoutSeconds }
                if ($timeout -lt 1 -or $timeout -gt 180) { throw 'thcrap.timeoutSeconds must be between 1 and 180.' }
                $thcrap = [pscustomobject]@{ loader=$loader; config=(Get-Item -LiteralPath $thcrap.config).FullName; workingDirectory=$workingDirectory; timeoutSeconds=$timeout }
            }
        }
        $built = Join-Path $RepoRoot "$Configuration\thprac.exe"
        if (!(Test-Path -LiteralPath $built)) { throw "Missing $built. Run scripts\build.ps1 -Configuration $Configuration first." }
        $id = [Guid]::NewGuid().ToString('N')
        $dir = Join-Path $DebugRoot "sessions\$id"
        $bin = Join-Path $dir 'bin'
        $data = Join-Path $bin '.thprac_data'
        New-Item -ItemType Directory -Force -Path $data | Out-Null
        Copy-Item -LiteralPath $built -Destination $bin
        $pdb = Join-Path $RepoRoot "$Configuration\thprac.pdb"
        if (Test-Path -LiteralPath $pdb) { Copy-Item -LiteralPath $pdb -Destination $bin }
        # Portable settings avoid changing the user's launcher configuration or
        # automatically attaching to unrelated games if explicit attachment fails.
        Write-DebugJson (Join-Path $data 'settings.json') @{ dont_search_ongoing_game=$true; existing_game_launch_action=1 }
        $state = [pscustomobject]@{
            schemaVersion=2; id=$id; phase='starting'; startedUtc=[DateTime]::UtcNow.ToString('o'); updatedUtc=$null
            targetGame=$Game; gamePath=$GamePath; configuration=$Configuration
            thpracPath=(Join-Path $bin 'thprac.exe'); outputDirectory=$dir
            worker=$null; thprac=$null; game=$null; loader=$null; thcrap=$thcrap; thcrapModule=$null; error=$null
        }
        Write-DebugJson (Join-Path $dir 'state.json') $state
        Write-DebugJson (Join-Path $DebugRoot 'session.json') @{ id=$id }
        $shell = (Get-Process -Id $PID).Path
        $workerArgs = '-NoProfile -File "{0}" -SessionDirectory "{1}"' -f (Join-Path $PSScriptRoot 'debug-worker.ps1'), $dir
        $worker = Start-Process -FilePath $shell -ArgumentList $workerArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $dir 'worker.stdout.log') -RedirectStandardError (Join-Path $dir 'worker.stderr.log')
        $startupSeconds = 20
        if ($thcrap) { $startupSeconds += $thcrap.timeoutSeconds }
        $deadline = [DateTime]::UtcNow.AddSeconds($startupSeconds)
        do {
            Start-Sleep -Milliseconds 200
            $state = Read-DebugJson (Join-Path $dir 'state.json')
            if ($state.phase -ne 'starting') { break }
            if ($worker.HasExited) { throw "Session worker exited. Inspect $dir\worker.stderr.log" }
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($state.phase -eq 'starting') {
            [IO.File]::WriteAllText((Join-Path $dir 'stop.request'), '')
            throw "Session startup timed out; cleanup requested. Inspect $dir and run stop."
        }
        if ($state.phase -eq 'failed') { throw "Session failed: $($state.error). Diagnostics: $dir" }
    }
    elseif (!$state) { Write-Output '{"phase":"no-session"}'; exit 0 }
    elseif ($Action -eq 'stop') {
        [IO.File]::WriteAllText((Join-Path $dir 'stop.request'), '')
        $worker = Get-OwnedProcess $state.worker
        if ($worker) {
            if (!$worker.WaitForExit(15000)) { throw 'Worker has not finished cleanup. Retry status/stop; no unrelated processes were terminated.' }
            $worker.Dispose()
        } else {
            foreach ($record in @($state.thprac, $state.game, $state.loader)) {
                $owned = Get-OwnedProcess $record
                if ($owned) {
                    try { Stop-OwnedProcess $owned; Update-ProcessRecord $owned $record }
                    finally { $owned.Dispose() }
                } elseif ($record -and $record.state -eq 'running') { $record.state='unavailable'; $record.exitCode=$null }
            }
            $state.phase = 'stopped'
            $state.updatedUtc = [DateTime]::UtcNow.ToString('o')
            Write-DebugJson (Join-Path $dir 'state.json') $state
        }
        $state = Read-DebugJson (Join-Path $dir 'state.json')
    }
    if ($Action -eq 'collect') { & "$PSScriptRoot\collect-debug.ps1" -SessionDirectory $dir; exit $LASTEXITCODE }
    # Refresh without overwriting the worker's state.
    $view = $state | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    foreach ($record in @($view.worker, $view.thprac, $view.game, $view.loader)) {
        if (!$record -or $record.state -eq 'exited') { continue }
        $live = Get-OwnedProcess $record
        if ($live) { $record.state='running'; $live.Dispose() }
        else { $record.state='unavailable' }
    }
    if ($view.phase -eq 'running' -and $view.worker.state -eq 'unavailable') { $view.phase='stale' }
    $view | ConvertTo-Json -Depth 12
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
finally { if ($lock) { $lock.Dispose() } }
