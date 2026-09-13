[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lock = $null
try {
    $logs = Join-Path $repo '.debug\build'
    New-Item -ItemType Directory -Force -Path $logs | Out-Null
    try { $lock = [IO.File]::Open((Join-Path $logs 'build.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Another build is running. Wait for it before rebuilding.' }
    $vswhere = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio Installer/vswhere.exe is missing. Visual Studio C++ Build Tools and a Windows SDK are required; no software was installed.' }
    $vs = & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$vs) { throw 'No Visual Studio installation with MSBuild and x86/x64 C++ tools was found.' }
    $msbuild = Join-Path $vs 'MSBuild\Current\Bin\MSBuild.exe'
    if (!(Test-Path -LiteralPath $msbuild)) { throw "MSBuild is missing at $msbuild" }
    & (Join-Path $vs 'Common7\Tools\Launch-VsDevShell.ps1') -Arch x86 -HostArch amd64 -SkipAutomaticLocation | Out-Host
    Push-Location (Join-Path $repo 'thprac')
    try {
        $helper = Join-Path $repo 'thprac\loc_json.exe'
        $inputs = @('loc_json.cpp', 'src\3rdParties\yyjson\yyjson.c', 'src\3rdParties\yyjson\yyjson.h')
        $rebuildHelper = !(Test-Path -LiteralPath $helper)
        if (!$rebuildHelper) {
            $modified = (Get-Item -LiteralPath $helper).LastWriteTimeUtc
            $rebuildHelper = @($inputs | Where-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc -gt $modified }).Count -gt 0
        }
        if ($rebuildHelper) {
            & cl.exe /Isrc\3rdParties\yyjson /nologo /EHsc /O2 /std:c++20 loc_json.cpp .\src\3rdParties\yyjson\yyjson.c /Fe:loc_json.exe 2>&1 |
                Tee-Object -FilePath (Join-Path $logs 'loc_json.log') | Out-Host
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    } finally { Pop-Location }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $log = Join-Path $logs "$Configuration-$stamp.log"
    Write-Host "Building $Configuration|x86 (project: Win32), using $msbuild"
    # Keep README/CI semantics. The generator compares contents before writing.
    & $msbuild (Join-Path $repo 'thprac.sln') '-t:restore,build' "-p:RestorePackagesConfig=true,Configuration=$Configuration,Platform=x86" '-nologo' "-flp:logfile=$log;verbosity=normal" "-bl:$logs\$Configuration-$stamp.binlog"
    $code = $LASTEXITCODE
    Write-Host "Build exit code: $code; log: $log"
    exit $code
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { if ($lock) { $lock.Dispose() } }