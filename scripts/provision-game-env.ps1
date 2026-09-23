[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GamesConfig,
    [string[]]$Game
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $repo '.debug\test-games'
$localConfigPath = Join-Path $repo 'debug.local.json'
$executables = @{
    ALCOSTG='alcostg.exe'; TH06='東方紅魔郷.exe'; TH07='th07.exe'; TH08='th08.exe'; TH09='th09.exe'
    TH095='th095.exe'; TH10='th10.exe'; TH11='th11.exe'; TH12='th12.exe'; TH125='th125.exe'
    TH128='th128.exe'; TH13='th13.exe'; TH14='th14.exe'; TH143='th143.exe'; TH15='th15.exe'
    TH16='th16.exe'; TH165='th165.exe'; TH17='th17.exe'; TH18='th18.exe'; TH185='th185.exe'
    TH19='th19.exe'; TH20='th20.exe'
}
if (!(Test-Path -LiteralPath $GamesConfig -PathType Leaf)) { throw "games.js not found: $GamesConfig" }
$sourceGames = Get-Content -LiteralPath $GamesConfig -Raw | ConvertFrom-Json
$config = if (Test-Path -LiteralPath $localConfigPath) { Get-Content -LiteralPath $localConfigPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{ games=[pscustomobject]@{} } }
if (!$config.games) { $config | Add-Member -NotePropertyName games -NotePropertyValue ([pscustomobject]@{}) }
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$testRootFull = [IO.Path]::GetFullPath($testRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$results = [System.Collections.Generic.List[object]]::new()
foreach ($name in $executables.Keys | Sort-Object) {
    if ($Game -and $name -notin $Game) { continue }
    $entry = $sourceGames.PSObject.Properties[$name.ToLowerInvariant()]
    if (!$entry) { $results.Add([pscustomobject]@{Game=$name; Status='MISSING_FROM_GAMES_JS'; Path=$null}); continue }
    $configured = [string]$entry.Value
    $source = [IO.Path]::GetDirectoryName($configured)
    $sourceExecutable = Join-Path $source $executables[$name]
    if (!(Test-Path -LiteralPath $configured -PathType Leaf)) { $results.Add([pscustomobject]@{Game=$name; Status='LAUNCHER_MISSING'; Path=$configured}); continue }
    if (!(Test-Path -LiteralPath $sourceExecutable -PathType Leaf)) { $results.Add([pscustomobject]@{Game=$name; Status='GAME_EXECUTABLE_MISSING'; Path=$sourceExecutable}); continue }

    $existing = $config.games.PSObject.Properties[$name]
    $existingPath = if ($existing -and $existing.Value -isnot [string]) { [string]$existing.Value.path } else { '' }
    if ($name -eq 'TH06' -and $existingPath -and [IO.Path]::GetFullPath($existingPath).StartsWith($testRootFull, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $existingPath -PathType Leaf)) {
        $copyExe = $existingPath
        $status = 'REUSED_TH06_COPY'
    } else {
        $hash = (Get-FileHash -LiteralPath $configured -Algorithm SHA256).Hash.Substring(0, 10).ToLowerInvariant()
        $copyDir = Join-Path $testRoot "$name-$hash-safe"
        $copyExe = Join-Path $copyDir $executables[$name]
        $marker = Join-Path $copyDir '.provisioned.json'
        if (!(Test-Path -LiteralPath $copyDir -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $copyDir | Out-Null
            foreach ($item in Get-ChildItem -LiteralPath $source -Force -Recurse -ErrorAction Stop) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                $relative = $item.FullName.Substring($source.Length).TrimStart([char[]]@('\','/'))
                $parts = $relative -split '[\\/]'
                if ($parts -contains 'replay') { continue }
                if (!$item.PSIsContainer -and ($item.Name -ieq 'score.dat' -or $item.Name -like 'score*.dat' -or $item.Name -like '*.rpy' -or $item.Name -like '*.rpy.thprac*')) { continue }
                $target = Join-Path $copyDir $relative
                if ($item.PSIsContainer) { New-Item -ItemType Directory -Force -Path $target | Out-Null }
                else {
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
                    Copy-Item -LiteralPath $item.FullName -Destination $target
                }
            }
            if (!(Test-Path -LiteralPath $copyExe -PathType Leaf)) { throw "Copy failed for $name. Inspect the partial test copy $copyDir." }
            $manifest = @{ source=$configured; sourceSha256=$hash; provisionedUtc=[DateTime]::UtcNow.ToString('o') }
            [IO.File]::WriteAllText($marker, ($manifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
            $status = 'COPIED'
        } elseif ((Test-Path -LiteralPath $marker -PathType Leaf) -and (Test-Path -LiteralPath $copyExe -PathType Leaf)) {
            $manifest = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
            if ($manifest.sourceSha256 -ne $hash) { throw "Copy source changed; inspect existing test copy $copyDir." }
            $status = 'REUSED_COPY'
        } else { throw "Partial test copy already exists; inspect manually before retrying: $copyDir" }
    }

    $launchPath = if ($name -eq 'TH06' -and $existingPath) { $copyExe } else { Join-Path ([IO.Path]::GetDirectoryName($copyExe)) ([IO.Path]::GetFileName($configured)) }
    if (!(Test-Path -LiteralPath $launchPath -PathType Leaf)) { throw "Configured launcher was not copied for ${name}: $launchPath" }
    $profile = [pscustomobject]@{ path=$launchPath; gameExe=$copyExe; appData=$true }
    if ($existing -and $existing.Value -isnot [string] -and $existing.Value.thcrap) { $profile | Add-Member -NotePropertyName thcrap -NotePropertyValue $existing.Value.thcrap }
    if ($existing) { $config.games.PSObject.Properties.Remove($name) }
    $config.games | Add-Member -NotePropertyName $name -NotePropertyValue $profile
    $results.Add([pscustomobject]@{Game=$name; Status=$status; Path=$copyExe})
}
[IO.File]::WriteAllText($localConfigPath, ($config | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
$results | Format-Table -AutoSize
