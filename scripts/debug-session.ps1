[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "status", "stop", "games")]
    [string]$Action = "status",
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string]$Name = "default",
    [string]$Game,
    [string]$GamePath,
    [string[]]$GameArgument = @(),
    [string[]]$ThpracArgument = @(),
    [string]$ThpracPath,
    [string]$ConfigPath,
    [switch]$LauncherOnly,
    [ValidateRange(1, 60)]
    [int]$StartupTimeoutSeconds = 10,
    [switch]$Force,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$defaultConfigPath = Join-Path $repoRoot ".codex\thprac-debug\config.json"
if (-not $ConfigPath) { $ConfigPath = $defaultConfigPath }
$sessionRoot = Join-Path $repoRoot ".codex\debug\sessions"
$statePath = Join-Path $sessionRoot "$Name.json"
New-Item -ItemType Directory -Force -Path $sessionRoot | Out-Null

# Touhou and thprac are Win32 processes. A 64-bit PowerShell host cannot enumerate
# their complete module lists, so transparently re-run this session command in the
# Windows 32-bit host. This keeps the normal Windows/WSL `powershell.exe -File ...` entrypoint.
if ([Environment]::Is64BitOperatingSystem -and [Environment]::Is64BitProcess) {
    $x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $x86PowerShell)) { throw "32-bit Windows PowerShell was not found at '$x86PowerShell'." }
    $forwardArguments = @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, $Action, "-Name", $Name)
    if ($Game) { $forwardArguments += @("-Game", $Game) }
    if ($GamePath) { $forwardArguments += @("-GamePath", $GamePath) }
    if ($GameArgument.Count -gt 0) { $forwardArguments += "-GameArgument"; $forwardArguments += $GameArgument }
    if ($ThpracArgument.Count -gt 0) { $forwardArguments += "-ThpracArgument"; $forwardArguments += $ThpracArgument }
    if ($ThpracPath) { $forwardArguments += @("-ThpracPath", $ThpracPath) }
    if ($ConfigPath) { $forwardArguments += @("-ConfigPath", $ConfigPath) }
    if ($LauncherOnly) { $forwardArguments += "-LauncherOnly" }
    $forwardArguments += @("-StartupTimeoutSeconds", [string]$StartupTimeoutSeconds)
    if ($Force) { $forwardArguments += "-Force" }
    if ($AsJson) { $forwardArguments += "-AsJson" }
    $forwardArgumentLine = ($forwardArguments | ForEach-Object { '"{0}"' -f ($_ -replace '"', '\"') }) -join " "
    $child = Start-Process -FilePath $x86PowerShell -ArgumentList $forwardArgumentLine -NoNewWindow -Wait -PassThru
    exit $child.ExitCode
}

function Get-OptionalProperty {
    param($Object, [string]$PropertyName)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $PropertyName) {
        return $Object.PSObject.Properties[$PropertyName].Value
    }
    return $null
}

function Resolve-LocalPath {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if (-not [System.IO.Path]::IsPathRooted($expanded)) { $expanded = Join-Path $repoRoot $expanded }
    return [System.IO.Path]::GetFullPath($expanded)
}

function Read-DebugConfig {
    param([switch]$Required)
    $resolvedConfigPath = Resolve-LocalPath -PathValue $ConfigPath
    if (-not (Test-Path -LiteralPath $resolvedConfigPath)) {
        if ($Required) {
            throw "Debug config was not found at '$resolvedConfigPath'. Copy '.codex\thprac-debug\config.example.json' to 'config.json' and edit it."
        }
        return $null
    }
    try {
        $config = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Debug config '$resolvedConfigPath' is not valid JSON: $($_.Exception.Message)"
    }
    $schemaVersion = Get-OptionalProperty -Object $config -PropertyName "schemaVersion"
    if ($null -ne $schemaVersion -and [int]$schemaVersion -ne 1) {
        throw "Unsupported debug config schemaVersion '$schemaVersion'. Expected 1."
    }
    return $config
}

function Get-ConfiguredGame {
    param($Config, [string]$GameName)
    $games = Get-OptionalProperty -Object $Config -PropertyName "games"
    if ($null -eq $games) { throw "Debug config does not define a 'games' object." }
    $gameProperty = $games.PSObject.Properties[$GameName]
    if ($null -eq $gameProperty) {
        $available = @($games.PSObject.Properties.Name) -join ", "
        throw "Game '$GameName' is not defined in the debug config. Available games: $available"
    }
    $gameConfig = $gameProperty.Value
    $configuredPath = Get-OptionalProperty -Object $gameConfig -PropertyName "path"
    if ([string]::IsNullOrWhiteSpace($configuredPath)) { throw "Game '$GameName' does not define a path." }
    return $gameConfig
}

function Get-GameConfigSummary {
    param($Config)
    $games = Get-OptionalProperty -Object $Config -PropertyName "games"
    $items = if ($games) {
        foreach ($property in $games.PSObject.Properties) {
            $configuredPath = Get-OptionalProperty -Object $property.Value -PropertyName "path"
            $resolvedPath = Resolve-LocalPath -PathValue $configuredPath
            $configuredProcessPath = Get-OptionalProperty -Object $property.Value -PropertyName "processPath"
            $processPath = if ([string]::IsNullOrWhiteSpace($configuredProcessPath)) { $null } else { Resolve-LocalPath -PathValue $configuredProcessPath }
            [pscustomobject]@{
                name = $property.Name
                launchMode = if (Get-OptionalProperty -Object $property.Value -PropertyName "launchMode") { Get-OptionalProperty -Object $property.Value -PropertyName "launchMode" } else { "direct" }
                path = $resolvedPath
                exists = ($resolvedPath -and (Test-Path -LiteralPath $resolvedPath))
                arguments = @(Get-OptionalProperty -Object $property.Value -PropertyName "arguments")
                processPath = $processPath
                processExists = if ($processPath) { Test-Path -LiteralPath $processPath } else { $null }
                requiredModules = @(Get-OptionalProperty -Object $property.Value -PropertyName "requiredModules" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                companionProcessNames = @(Get-OptionalProperty -Object $property.Value -PropertyName "companionProcessNames" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        }
    }
    return [pscustomobject]@{
        schemaVersion = 1
        configPath = Resolve-LocalPath -PathValue $ConfigPath
        defaultGame = Get-OptionalProperty -Object $Config -PropertyName "defaultGame"
        thpracPath = Resolve-LocalPath -PathValue (Get-OptionalProperty -Object $Config -PropertyName "thpracPath")
        games = @($items)
    }
}

function Read-SessionState {
    if (-not (Test-Path -LiteralPath $statePath)) { return $null }
    return Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

function Write-SessionState {
    param($State)
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8
}

function Get-LiveProcess {
    param($Entry)
    $process = Get-Process -Id ([int]$Entry.id) -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    try {
        $actualStart = $process.StartTime.ToUniversalTime()
        $expectedStart = [datetime]::Parse($Entry.startedAtUtc).ToUniversalTime()
        if ([math]::Abs(($actualStart - $expectedStart).TotalSeconds) -gt 2) { return $null }
    }
    catch { return $null }
    return $process
}

function Get-SessionStatus {
    param($State)
    if (-not $State) {
        return [pscustomobject]@{ schemaVersion = 1; name = $Name; exists = $false; active = $false; statePath = $statePath; processes = @() }
    }
    $processes = foreach ($entry in @($State.processes)) {
        $live = Get-LiveProcess -Entry $entry
        $requiredModules = @(Get-OptionalProperty -Object $entry -PropertyName "requiredModules" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $loadedRequiredModules = @()
        if ($live -and $requiredModules.Count -gt 0) {
            try {
                $loadedModuleNames = @($live.Modules | ForEach-Object ModuleName)
                $loadedRequiredModules = @($requiredModules | Where-Object { $loadedModuleNames -contains $_ })
            }
            catch { $loadedRequiredModules = @() }
        }
        [pscustomobject]@{
            role = $entry.role
            id = [int]$entry.id
            path = $entry.path
            running = ($null -ne $live)
            mainWindowTitle = if ($live) { $live.MainWindowTitle } else { $null }
            requiredModules = $requiredModules
            loadedRequiredModules = $loadedRequiredModules
            integrationReady = if ($requiredModules.Count -gt 0) { $live -and $loadedRequiredModules.Count -eq $requiredModules.Count } else { $null }
        }
    }
    return [pscustomobject]@{
        schemaVersion = 1
        name = $Name
        exists = $true
        active = (@($processes | Where-Object running).Count -gt 0)
        startedAtUtc = $State.startedAtUtc
        stoppedAtUtc = if ($State.PSObject.Properties.Name -contains "stoppedAtUtc") { $State.stoppedAtUtc } else { $null }
        configPath = Get-OptionalProperty -Object $State -PropertyName "configPath"
        game = Get-OptionalProperty -Object $State -PropertyName "game"
        gamePath = Get-OptionalProperty -Object $State -PropertyName "gamePath"
        launchMode = Get-OptionalProperty -Object $State -PropertyName "launchMode"
        statePath = $statePath
        logDirectory = $State.logDirectory
        processes = @($processes)
    }
}

function Write-Result {
    param($Result)
    if ($AsJson) { $Result | ConvertTo-Json -Depth 8; return }
    Write-Host "Session: $($Result.name)"
    Write-Host "Active:  $($Result.active)"
    if ($Result.exists) {
        Write-Host "State:   $($Result.statePath)"
        Write-Host "Logs:    $($Result.logDirectory)"
        if ($Result.game) { Write-Host "Game:    $($Result.game) -> $($Result.gamePath)" }
        if ($Result.launchMode) { Write-Host "Mode:    $($Result.launchMode)" }
        if ($Result.configPath) { Write-Host "Config:  $($Result.configPath)" }
        foreach ($process in @($Result.processes)) {
            Write-Host ("{0,-8} PID {1,-7} running={2} {3}" -f $process.role, $process.id, $process.running, $process.path)
            if (@($process.requiredModules).Count -gt 0) {
                Write-Host ("         integration={0} requiredModules={1}" -f $process.integrationReady, (@($process.requiredModules) -join ","))
            }
        }
    }
}

function Start-DetachedProcess {
    param([string]$Path, [string[]]$Arguments, [string]$WorkingDirectory)
    $argumentLine = (@($Arguments) | ForEach-Object { '"{0}"' -f ($_ -replace '"', '\"') }) -join " "
    $commandLine = '"{0}"' -f ($Path -replace '"', '\"')
    if ($argumentLine) { $commandLine = "$commandLine $argumentLine" }
    $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = $commandLine
        CurrentDirectory = $WorkingDirectory
    }
    if ([int]$result.ReturnValue -ne 0) {
        throw "Win32_Process.Create failed for '$Path' with return value $($result.ReturnValue)."
    }
    return [int](Get-OptionalProperty -Object $result -PropertyName "ProcessId")
}

function Find-NewGameProcesses {
    param([string[]]$Names, [int[]]$BaselineIds, [string]$ExpectedPath)
    $candidates = @(Get-Process -Name $Names -ErrorAction SilentlyContinue |
        Where-Object { $BaselineIds -notcontains $_.Id -and -not $_.HasExited })
    if ($ExpectedPath) {
        $candidates = @($candidates | Where-Object {
            try { [string]::Equals($_.Path, $ExpectedPath, [StringComparison]::OrdinalIgnoreCase) }
            catch { $false }
        })
    }
    return $candidates
}

function Stop-TrackedProcesses {
    param($State)
    $liveProcesses = foreach ($entry in @($State.processes)) { Get-LiveProcess -Entry $entry }
    foreach ($process in @($liveProcesses)) {
        if ($process -and $process.MainWindowHandle -ne 0) { [void]$process.CloseMainWindow() }
    }
    $deadline = (Get-Date).AddSeconds(3)
    do {
        Start-Sleep -Milliseconds 200
        $remaining = foreach ($entry in @($State.processes)) { Get-LiveProcess -Entry $entry }
    } while (@($remaining).Count -gt 0 -and (Get-Date) -lt $deadline)
    foreach ($process in @($remaining)) {
        if ($process) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    }
}

switch ($Action) {
    "games" {
        $summary = Get-GameConfigSummary -Config (Read-DebugConfig -Required)
        if ($AsJson) { $summary | ConvertTo-Json -Depth 8; exit 0 }
        Write-Host "Config:  $($summary.configPath)"
        Write-Host "Default: $($summary.defaultGame)"
        foreach ($item in @($summary.games)) {
            Write-Host ("{0,-12} mode={1,-14} exists={2} {3}" -f $item.name, $item.launchMode, $item.exists, $item.path)
            if ($item.processPath) {
                Write-Host ("             targetExists={0} {1}" -f $item.processExists, $item.processPath)
            }
        }
        exit 0
    }
    "status" {
        Write-Result (Get-SessionStatus -State (Read-SessionState))
        exit 0
    }
    "start" {
        if ($LauncherOnly -and ($Game -or $GamePath)) { throw "-LauncherOnly cannot be combined with -Game or -GamePath." }
        if ($Game -and $GamePath) { throw "Use either -Game (config alias) or -GamePath, not both." }
        $config = Read-DebugConfig
        $selectedGame = $Game
        $gameLaunchMode = "direct"
        $gameProcessPath = $null
        $gameProcessNames = @()
        $requiredModules = @()
        $companionProcessNames = @()
        if (-not $LauncherOnly -and -not $GamePath -and -not $selectedGame -and $config) {
            $selectedGame = Get-OptionalProperty -Object $config -PropertyName "defaultGame"
        }
        if (-not $LauncherOnly -and $selectedGame) {
            if (-not $config) { $config = Read-DebugConfig -Required }
            $gameConfig = Get-ConfiguredGame -Config $config -GameName $selectedGame
            $GamePath = Get-OptionalProperty -Object $gameConfig -PropertyName "path"
            $configuredArguments = @(Get-OptionalProperty -Object $gameConfig -PropertyName "arguments")
            $GameArgument = @($configuredArguments + $GameArgument)
            $configuredLaunchMode = Get-OptionalProperty -Object $gameConfig -PropertyName "launchMode"
            if ($configuredLaunchMode) { $gameLaunchMode = $configuredLaunchMode }
            $gameProcessPath = Get-OptionalProperty -Object $gameConfig -PropertyName "processPath"
            $gameProcessNames = @(Get-OptionalProperty -Object $gameConfig -PropertyName "processNames" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $requiredModules = @(Get-OptionalProperty -Object $gameConfig -PropertyName "requiredModules" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $companionProcessNames = @(Get-OptionalProperty -Object $gameConfig -PropertyName "companionProcessNames" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        if ($gameLaunchMode -notin @("direct", "externalAttach")) { throw "Unsupported launchMode '$gameLaunchMode'. Expected 'direct' or 'externalAttach'." }
        if ($gameLaunchMode -eq "externalAttach" -and -not $GamePath) { throw "launchMode 'externalAttach' requires a configured game path." }
        if (-not $ThpracPath -and $config) {
            $ThpracPath = Get-OptionalProperty -Object $config -PropertyName "thpracPath"
        }

        $previous = Read-SessionState
        $previousStatus = Get-SessionStatus -State $previous
        if ($previousStatus.active -and -not $Force) { throw "Session '$Name' is already active. Stop it first or pass -Force to replace it." }
        if ($previousStatus.active -and $Force) {
            Stop-TrackedProcesses -State $previous
            $previous.stoppedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
            Write-SessionState -State $previous
        }

        if (-not $ThpracPath) { $ThpracPath = "Debug\thprac.exe" }
        $ThpracPath = (Resolve-Path -LiteralPath (Resolve-LocalPath -PathValue $ThpracPath) -ErrorAction Stop).Path
        if ($GamePath) { $GamePath = (Resolve-Path -LiteralPath (Resolve-LocalPath -PathValue $GamePath) -ErrorAction Stop).Path }
        if ($gameProcessPath) { $gameProcessPath = (Resolve-Path -LiteralPath (Resolve-LocalPath -PathValue $gameProcessPath) -ErrorAction Stop).Path }

        $runId = Get-Date -Format "yyyyMMdd-HHmmss-fff"
        $runDirectory = Join-Path (Join-Path $sessionRoot $Name) $runId
        New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
        $baselineIds = @((Get-Process -ErrorAction SilentlyContinue).Id)
        "Detached GUI process; use Windows Application Error/WER events for runtime failures." |
            Set-Content -LiteralPath (Join-Path $runDirectory "thprac.stdout.log") -Encoding UTF8
        "Detached GUI process; stderr is not available for this Windows subsystem executable." |
            Set-Content -LiteralPath (Join-Path $runDirectory "thprac.stderr.log") -Encoding UTF8

        $tracked = @()
        if ($gameLaunchMode -eq "externalAttach") {
            $launcherProcessId = Start-DetachedProcess -Path $GamePath -Arguments $GameArgument -WorkingDirectory (Split-Path -Parent $GamePath)
            $launcherProcess = Get-Process -Id $launcherProcessId -ErrorAction SilentlyContinue
            if ($launcherProcess) {
                $tracked += [pscustomobject]@{
                    role = "launcher"; id = $launcherProcess.Id; path = $GamePath
                    startedAtUtc = $launcherProcess.StartTime.ToUniversalTime().ToString("o"); requiredModules = @()
                }
            }

            if ($gameProcessNames.Count -eq 0 -and $gameProcessPath) {
                $gameProcessNames = @([System.IO.Path]::GetFileNameWithoutExtension($gameProcessPath))
            }
            if ($gameProcessNames.Count -eq 0) {
                Stop-TrackedProcesses -State ([pscustomobject]@{ processes = @($tracked) })
                throw "launchMode 'externalAttach' requires processPath or processNames so the launched game can be identified."
            }

            $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
            do {
                Start-Sleep -Milliseconds 250
                $gameProcesses = @(Find-NewGameProcesses -Names $gameProcessNames -BaselineIds $baselineIds -ExpectedPath $gameProcessPath)
            } while ($gameProcesses.Count -eq 0 -and (Get-Date) -lt $deadline)
            if ($gameProcesses.Count -eq 0) {
                Stop-TrackedProcesses -State ([pscustomobject]@{ processes = @($tracked) })
                throw "The external launcher ran, but the configured game process did not appear within $StartupTimeoutSeconds seconds."
            }

            $gameProcess = @($gameProcesses | Sort-Object StartTime -Descending)[0]
            if ($companionProcessNames.Count -gt 0) {
                $companionProcesses = @(Get-Process -Name $companionProcessNames -ErrorAction SilentlyContinue |
                    Where-Object { $baselineIds -notcontains $_.Id -and -not $_.HasExited })
                foreach ($companionProcess in $companionProcesses) {
                    $tracked += [pscustomobject]@{
                        role = "companion"; id = $companionProcess.Id; path = $companionProcess.Path
                        startedAtUtc = $companionProcess.StartTime.ToUniversalTime().ToString("o"); requiredModules = @()
                    }
                }
            }
            if ($requiredModules.Count -gt 0) {
                $moduleDeadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
                do {
                    try { $loadedModuleNames = @($gameProcess.Modules | ForEach-Object ModuleName) } catch { $loadedModuleNames = @() }
                    $missingModules = @($requiredModules | Where-Object { $loadedModuleNames -notcontains $_ })
                    if ($missingModules.Count -gt 0) { Start-Sleep -Milliseconds 250 }
                } while ($missingModules.Count -gt 0 -and (Get-Date) -lt $moduleDeadline)
                if ($missingModules.Count -gt 0) {
                    $tracked += [pscustomobject]@{
                        role = "game"; id = $gameProcess.Id; path = $gameProcess.Path
                        startedAtUtc = $gameProcess.StartTime.ToUniversalTime().ToString("o"); requiredModules = $requiredModules
                    }
                    Stop-TrackedProcesses -State ([pscustomobject]@{ processes = @($tracked) })
                    throw "The game launched, but required integration modules were not loaded: $($missingModules -join ', ')."
                }
            }
            $tracked += [pscustomobject]@{
                role = "game"; id = $gameProcess.Id; path = $gameProcess.Path
                startedAtUtc = $gameProcess.StartTime.ToUniversalTime().ToString("o"); requiredModules = $requiredModules
            }
            $launchArguments = @("--attach", [string]$gameProcess.Id) + @($ThpracArgument)
        }
        else {
            $launchArguments = @()
            if ($GamePath) { $launchArguments += $GamePath; $launchArguments += $GameArgument }
            $launchArguments += $ThpracArgument
        }

        $createdProcessId = Start-DetachedProcess -Path $ThpracPath -Arguments $launchArguments -WorkingDirectory (Split-Path -Parent $ThpracPath)
        $thpracProcess = $null
        if ($createdProcessId) {
            $processDeadline = (Get-Date).AddSeconds(2)
            do {
                $thpracProcess = Get-Process -Id ([int]$createdProcessId) -ErrorAction SilentlyContinue
                if (-not $thpracProcess) { Start-Sleep -Milliseconds 100 }
            } while (-not $thpracProcess -and (Get-Date) -lt $processDeadline)
        }
        if ($thpracProcess) {
            $tracked += [pscustomobject]@{
                role = "thprac"
                id = $thpracProcess.Id
                path = $ThpracPath
                startedAtUtc = $thpracProcess.StartTime.ToUniversalTime().ToString("o")
                requiredModules = @()
            }
        }

        if ($GamePath -and $gameLaunchMode -eq "direct") {
            $gameProcessNames = @([System.IO.Path]::GetFileNameWithoutExtension($GamePath))
            if ($selectedGame) { $gameProcessNames += $selectedGame }
            $gameProcessNames = @($gameProcessNames | Select-Object -Unique)
            $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
            do {
                Start-Sleep -Milliseconds 250
                $gameProcesses = Get-Process -Name $gameProcessNames -ErrorAction SilentlyContinue |
                    Where-Object { $baselineIds -notcontains $_.Id }
            } while (-not $gameProcesses -and (Get-Date) -lt $deadline)

            # Steam and other launchers may replace the first short-lived process.
            # Re-scan after a brief stabilization window and record the live PID.
            Start-Sleep -Milliseconds 1500
            $stabilityDeadline = (Get-Date).AddSeconds(3)
            do {
                $stableGameProcesses = Get-Process -Name $gameProcessNames -ErrorAction SilentlyContinue |
                    Where-Object { $baselineIds -notcontains $_.Id }
                if (-not $stableGameProcesses) { Start-Sleep -Milliseconds 250 }
            } while (-not $stableGameProcesses -and (Get-Date) -lt $stabilityDeadline)
            if ($stableGameProcesses) { $gameProcesses = $stableGameProcesses }

            foreach ($candidateProcess in @($gameProcesses | Where-Object { $null -ne $_ -and -not $_.HasExited })) {
                if ($candidateProcess) {
                    try { $actualPath = $candidateProcess.Path } catch { $actualPath = $GamePath }
                    $tracked += [pscustomobject]@{ role = "game"; id = $candidateProcess.Id; path = $actualPath; startedAtUtc = $candidateProcess.StartTime.ToUniversalTime().ToString("o"); requiredModules = @() }
                }
            }
        }

        if ($GamePath -and @($tracked | Where-Object role -eq "game").Count -eq 0) {
            foreach ($entry in @($tracked)) {
                $liveProcess = Get-LiveProcess -Entry $entry
                if ($liveProcess) { Stop-Process -Id $liveProcess.Id -Force -ErrorAction SilentlyContinue }
            }
            throw "No live process matching the configured game appeared within the startup window."
        }
        if (@($tracked).Count -eq 0) {
            throw "thprac exited and no configured game process appeared within $StartupTimeoutSeconds seconds."
        }

        $state = [pscustomobject]@{
            schemaVersion = 1
            name = $Name
            runId = $runId
            startedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
            stoppedAtUtc = $null
            configPath = if ($config) { Resolve-LocalPath -PathValue $ConfigPath } else { $null }
            game = $selectedGame
            thpracPath = $ThpracPath
            gamePath = $GamePath
            launchMode = $gameLaunchMode
            arguments = $launchArguments
            logDirectory = $runDirectory
            processes = @($tracked)
        }
        Write-SessionState -State $state
        Start-Sleep -Milliseconds 500
        Write-Result (Get-SessionStatus -State $state)
        exit 0
    }
    "stop" {
        $state = Read-SessionState
        if (-not $state) { Write-Result (Get-SessionStatus -State $null); exit 0 }
        Stop-TrackedProcesses -State $state
        $state.stoppedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        Write-SessionState -State $state
        Write-Result (Get-SessionStatus -State $state)
        exit 0
    }
}
