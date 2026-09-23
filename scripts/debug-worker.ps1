param([Parameter(Mandatory)][string]$SessionDirectory)
. "$PSScriptRoot\debug-common.ps1"
$statePath = Join-Path $SessionDirectory 'state.json'
$state = Read-DebugJson $statePath
$gameProcess = $null
$thpracProcess = $null
$loaderProcess = $null
$launcherProcess = $null
$job = $null
try {
    if ($state.appDataPath) {
        $sessionRoot = [IO.Path]::GetFullPath($SessionDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (![IO.Path]::GetFullPath($state.appDataPath).StartsWith($sessionRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Isolated AppData must be inside the managed session.'
        }
        New-Item -ItemType Directory -Force -Path $state.appDataPath | Out-Null
        $env:APPDATA = $state.appDataPath
    }
    $state.worker = Get-ProcessRecord (Get-Process -Id $PID) (Get-Process -Id $PID).Path
    Write-DebugJson $statePath $state
    if ($state.gamePath) {
        if ($state.thcrap) {
            Add-Type -Path "$PSScriptRoot\DebugJob.cs"
            # Avoid the loader's ANSI command-line extension detection for Unicode
            # executable names. Its runconfig merge handles the UTF-8 exe field.
            $targetConfig = Join-Path $SessionDirectory 'thcrap-target.js'
            Write-DebugJson $targetConfig @{ exe=$state.gamePath }
            $job = [ThpracDebugJob]::new($state.thcrap.loader, [string[]]@($state.thcrap.config, $targetConfig), $state.thcrap.workingDirectory)
            $loaderProcess = $job.Root
            $state.loader = Get-ProcessRecord $loaderProcess $state.thcrap.loader
            Write-DebugJson $statePath $state
            $deadline = [DateTime]::UtcNow.AddSeconds($state.thcrap.timeoutSeconds)
            do {
                if (Test-Path -LiteralPath (Join-Path $SessionDirectory 'stop.request')) { throw 'Startup cancelled.' }
                foreach ($candidate in $job.Processes()) {
                    if ($candidate.Path -ieq $state.gamePath) {
                        if ($gameProcess) { $candidate.Dispose(); throw 'Multiple matching game processes in the session job; refusing ambiguous attachment.' }
                        $gameProcess = $candidate
                    }
                    else { $candidate.Dispose() }
                }
                Update-ProcessRecord $loaderProcess $state.loader
                if ($gameProcess) { break }
                if ($loaderProcess.HasExited -and $loaderProcess.ExitCode -ne 0) {
                    throw "thcrap loader failed with exit code $($loaderProcess.ExitCode)."
                }
                Start-Sleep -Milliseconds 100
            } while ([DateTime]::UtcNow -lt $deadline)
            if (!$gameProcess) { throw 'Timed out waiting for the configured game inside the thcrap session job.' }
        } elseif ($state.launchPath -and $state.launchPath -ine $state.gamePath) {
            Add-Type -Path "$PSScriptRoot\DebugJob.cs"
            $job = [ThpracDebugJob]::new($state.launchPath, [string[]]@(), [IO.Path]::GetDirectoryName($state.launchPath))
            $launcherProcess = $job.Root
            $state.launcher = Get-ProcessRecord $launcherProcess $state.launchPath
            Write-DebugJson $statePath $state
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            do {
                if (Test-Path -LiteralPath (Join-Path $SessionDirectory 'stop.request')) { throw 'Startup cancelled.' }
                foreach ($candidate in $job.Processes()) {
                    if ($candidate.Path -ieq $state.gamePath) {
                        if ($gameProcess) { $candidate.Dispose(); throw 'Multiple matching game processes in the session job; refusing ambiguous attachment.' }
                        $gameProcess = $candidate
                    } else { $candidate.Dispose() }
                }
                Update-ProcessRecord $launcherProcess $state.launcher
                if ($gameProcess) { break }
                if ($launcherProcess.HasExited -and $launcherProcess.ExitCode -ne 0) {
                    throw "Configured launcher exited with code $($launcherProcess.ExitCode)."
                }
                Start-Sleep -Milliseconds 100
            } while ([DateTime]::UtcNow -lt $deadline)
            if (!$gameProcess) { throw "Configured launcher did not start $($state.gamePath) inside the managed session." }
        } else {
            if ($state.targetGame -ieq 'TH06NC') {
                # The Steam client is still required. Supply its application
                # identity for a direct debug launch so the retained process
                # does not exit/relaunch outside this managed session.
                # These variables exist only in this worker and its children.
                $env:SteamAppId = '4659620'
                $env:SteamGameId = '4659620'
            }
            $gameProcess = Start-Process -FilePath $state.gamePath -WorkingDirectory (Split-Path $state.gamePath -Parent) -PassThru -WindowStyle Normal
        }
        $state.game = Get-ProcessRecord $gameProcess $state.gamePath
        Write-DebugJson $statePath $state
        $idle = $false
        try { $idle = $gameProcess.WaitForInputIdle(10000) } catch { }
        if ($gameProcess.HasExited) { throw "Game exited before attachment: $($gameProcess.ExitCode)" }
        if ($state.thcrap) {
            if (!$idle) { throw 'thcrap game did not finish GUI initialization before attachment.' }
            $module = @($gameProcess.Modules | Where-Object { $_.ModuleName -match '^thcrap(_d)?\.dll$' })
            if (!$module.Count) { throw 'The session game has no loaded thcrap DLL; refusing unpatched attachment.' }
            $state.thcrapModule = $module[0].FileName
            Write-DebugJson $statePath $state
        }
    }
    $launch = @{ FilePath=$state.thpracPath; WorkingDirectory=(Split-Path $state.thpracPath -Parent); PassThru=$true; WindowStyle='Normal' }
    if ($gameProcess) { $launch.ArgumentList = @('--attach', "$($gameProcess.Id)") }
    $thpracProcess = Start-Process @launch
    $state.thprac = Get-ProcessRecord $thpracProcess $state.thpracPath
    $state.phase = 'running'
    do {
        Update-ProcessRecord $gameProcess $state.game
        Update-ProcessRecord $thpracProcess $state.thprac
        Update-ProcessRecord $loaderProcess $state.loader
        Update-ProcessRecord $launcherProcess $state.launcher
        $state.updatedUtc = [DateTime]::UtcNow.ToString('o')
        Write-DebugJson $statePath $state
        if (Test-Path -LiteralPath (Join-Path $SessionDirectory 'stop.request')) { break }
        if ($thpracProcess.HasExited -and (!$gameProcess -or $gameProcess.HasExited)) { break }
        Start-Sleep -Milliseconds 500
    } while ($true)
    $state.phase = 'stopped'
} catch { $state.phase = 'failed'; $state.error = $_.Exception.Message }
finally {
    foreach ($process in @($thpracProcess, $gameProcess, $loaderProcess, $launcherProcess)) {
        try { Stop-OwnedProcess $process }
        catch { $state.error += " Cleanup: $($_.Exception.Message)"; $state.phase = 'failed' }
    }
    Update-ProcessRecord $gameProcess $state.game
    Update-ProcessRecord $thpracProcess $state.thprac
    Update-ProcessRecord $loaderProcess $state.loader
    Update-ProcessRecord $launcherProcess $state.launcher
    if ($job) { $job.Dispose() }
    $state.updatedUtc = [DateTime]::UtcNow.ToString('o')
    Write-DebugJson $statePath $state
}
