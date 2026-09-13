[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string]$Name = "default",
    [string]$OutputDirectory,
    [switch]$NoArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$debugRoot = Join-Path $repoRoot ".codex\debug"
$statePath = Join-Path (Join-Path $debugRoot "sessions") "$Name.json"
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "Debug session '$Name' does not exist. Start it with scripts/debug-session.ps1 first."
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Join-Path $debugRoot "collections") "$Name-$timestamp" }
$bundleDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $bundleDirectory | Out-Null

Copy-Item -LiteralPath $statePath -Destination (Join-Path $bundleDirectory "session.json")
if (Test-Path -LiteralPath $state.logDirectory) {
    Copy-Item -LiteralPath $state.logDirectory -Destination (Join-Path $bundleDirectory "session-logs") -Recurse -Force
}
& (Join-Path $PSScriptRoot "debug-session.ps1") status -Name $Name -AsJson |
    Set-Content -LiteralPath (Join-Path $bundleDirectory "status.json") -Encoding UTF8

$processDetails = foreach ($entry in @($state.processes)) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($entry.id)" -ErrorAction SilentlyContinue
    [pscustomobject]@{ role = $entry.role; expectedId = [int]$entry.id; expectedPath = $entry.path; running = ($null -ne $process); process = $process }
}
$processDetails | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $bundleDirectory "processes.json") -Encoding UTF8

Get-ComputerInfo -Property WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture -ErrorAction SilentlyContinue |
    ConvertTo-Json -Depth 3 |
    Set-Content -LiteralPath (Join-Path $bundleDirectory "system.json") -Encoding UTF8

$eventErrors = @()
try {
    $startTime = [datetime]::Parse($state.startedAtUtc).ToLocalTime().AddMinutes(-1)
    $names = @($state.processes | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.path) })
    $ids = @($state.processes | ForEach-Object { [string]$_.id })
    $eventErrors = Get-WinEvent -FilterHashtable @{ LogName = "Application"; StartTime = $startTime; Level = 1, 2, 3 } -ErrorAction Stop |
        Where-Object {
            $eventRecord = $_
            $nameMatched = @($names | Where-Object { $_ -and $eventRecord.Message -match [regex]::Escape($_) }).Count -gt 0
            $idMatched = @($ids | Where-Object { $_ -and $eventRecord.Message -match "\b$([regex]::Escape($_))\b" }).Count -gt 0
            $eventRecord.ProviderName -in @("Application Error", "Windows Error Reporting", ".NET Runtime") -and ($nameMatched -or $idMatched)
        } |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
}
catch {
    if ($_.FullyQualifiedErrorId -notmatch "NoMatchingEventsFound") {
        $_ | Out-String | Set-Content -LiteralPath (Join-Path $bundleDirectory "event-log-error.txt") -Encoding UTF8
    }
}
$eventJson = if (@($eventErrors).Count -eq 0) { "[]" } else { ConvertTo-Json -InputObject @($eventErrors) -Depth 4 }
$eventJson | Set-Content -LiteralPath (Join-Path $bundleDirectory "application-events.json") -Encoding UTF8

$dumpDirectory = Join-Path $bundleDirectory "dumps"
$dumpCandidates = @(
    (Join-Path $env:LOCALAPPDATA "CrashDumps"),
    (Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportArchive"),
    $state.logDirectory
) | Select-Object -Unique
$sessionStart = [datetime]::Parse($state.startedAtUtc).ToLocalTime().AddMinutes(-1)
foreach ($candidate in $dumpCandidates) {
    if (-not (Test-Path -LiteralPath $candidate)) { continue }
    Get-ChildItem -LiteralPath $candidate -Filter "*.dmp" -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $sessionStart } |
        ForEach-Object {
            New-Item -ItemType Directory -Force -Path $dumpDirectory | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dumpDirectory $_.Name) -Force
        }
}

$latestBuild = Join-Path (Join-Path $debugRoot "build") "latest.json"
if (Test-Path -LiteralPath $latestBuild) {
    Copy-Item -LiteralPath $latestBuild -Destination (Join-Path $bundleDirectory "latest-build.json")
    $build = Get-Content -LiteralPath $latestBuild -Raw | ConvertFrom-Json
    foreach ($log in @($build.consoleLog, $build.errorLog, $build.helperLog, $build.helperErrorLog, $build.diagnosticLog)) {
        if ($log -and (Test-Path -LiteralPath $log)) {
            Copy-Item -LiteralPath $log -Destination (Join-Path $bundleDirectory ([System.IO.Path]::GetFileName($log))) -Force
        }
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    session = $Name
    collectedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    bundleDirectory = $bundleDirectory
    eventCount = @($eventErrors).Count
    dumpCount = if (Test-Path -LiteralPath $dumpDirectory) { @(Get-ChildItem -LiteralPath $dumpDirectory -File).Count } else { 0 }
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $bundleDirectory "manifest.json") -Encoding UTF8

if ($NoArchive) { Write-Output $bundleDirectory; exit 0 }
$archivePath = "$bundleDirectory.zip"
Compress-Archive -Path (Join-Path $bundleDirectory "*") -DestinationPath $archivePath -Force
Write-Output $archivePath
