[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release", "DebugLLVM", "ReleaseLLVM")]
    [string]$Configuration = "Release",
    [ValidateSet("x86")]
    [string]$Platform = "x86",
    [string]$MSBuildPath,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$solutionPath = Join-Path $repoRoot "thprac.sln"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logRoot = Join-Path $repoRoot ".codex\debug\build"
$runLogRoot = Join-Path $logRoot "$timestamp-$Configuration"
$consoleLog = Join-Path $runLogRoot "console.log"
$errorLog = Join-Path $runLogRoot "stderr.log"
$helperLog = Join-Path $runLogRoot "loc-json.log"
$helperErrorLog = Join-Path $runLogRoot "loc-json-stderr.log"
$diagnosticLog = Join-Path $runLogRoot "msbuild-diagnostic.log"
$binaryLog = Join-Path $runLogRoot "msbuild.binlog"
$metadataPath = Join-Path $runLogRoot "build.json"
$latestPath = Join-Path $logRoot "latest.json"
New-Item -ItemType Directory -Force -Path $runLogRoot | Out-Null

function Find-MSBuild {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        return (Resolve-Path -LiteralPath $RequestedPath -ErrorAction Stop).Path
    }

    $vswhereCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"),
        (Join-Path $env:ProgramFiles "Microsoft Visual Studio\Installer\vswhere.exe")
    ) | Select-Object -Unique

    foreach ($vswhere in $vswhereCandidates) {
        if (-not (Test-Path -LiteralPath $vswhere)) { continue }
        try {
            $found = & $vswhere -latest -prerelease -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" 2>$null | Select-Object -First 1
            if ($found -and (Test-Path -LiteralPath $found)) {
                return (Resolve-Path -LiteralPath $found).Path
            }
        }
        catch {
            Write-Verbose "vswhere could not be executed: $($_.Exception.Message)"
        }
    }

    $visualStudioRoots = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio"),
        (Join-Path $env:ProgramFiles "Microsoft Visual Studio")
    ) | Select-Object -Unique

    $fallbacks = foreach ($root in $visualStudioRoots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Filter "MSBuild.exe" -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\MSBuild\\Current\\Bin\\(?:amd64\\)?MSBuild\.exe$' }
        }
    }

    $preferred = $fallbacks |
        Sort-Object @{ Expression = { if ($_.FullName -match '\\Bin\\MSBuild\.exe$') { 0 } else { 1 } } }, @{ Expression = { $_.FullName }; Descending = $true } |
        Select-Object -First 1
    if ($preferred) { return $preferred.FullName }

    throw "MSBuild.exe was not found. Install Visual Studio Build Tools with Desktop development with C++, or pass -MSBuildPath."
}

function Find-VisualCppEnvironment {
    param([string]$ResolvedMSBuild)
    $cursor = Split-Path -Parent $ResolvedMSBuild
    while ($cursor) {
        $toolsetsRoot = Join-Path $cursor "VC\Tools\MSVC"
        if (Test-Path -LiteralPath $toolsetsRoot) { break }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
    if (-not (Test-Path -LiteralPath $toolsetsRoot)) {
        throw "The Visual C++ toolset was not found beside MSBuild at '$ResolvedMSBuild'."
    }

    $toolset = Get-ChildItem -LiteralPath $toolsetsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "bin\Hostx64\x86\cl.exe") } |
        Sort-Object @{ Expression = { try { [version]$_.Name } catch { [version]"0.0" } }; Descending = $true } |
        Select-Object -First 1
    if (-not $toolset) { throw "cl.exe (Hostx64/x86) was not found under '$toolsetsRoot'." }

    $sdkRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10"
    $sdkIncludeRoot = Join-Path $sdkRoot "Include"
    $sdkVersion = Get-ChildItem -LiteralPath $sdkIncludeRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "um\Windows.h") } |
        Sort-Object @{ Expression = { try { [version]$_.Name } catch { [version]"0.0" } }; Descending = $true } |
        Select-Object -First 1
    if (-not $sdkVersion) { throw "A Windows 10/11 SDK was not found under '$sdkRoot'." }

    $sdkVersionName = $sdkVersion.Name
    return [pscustomobject]@{
        cl = Join-Path $toolset.FullName "bin\Hostx64\x86\cl.exe"
        path = @(
            (Join-Path $toolset.FullName "bin\Hostx64\x86"),
            (Join-Path $sdkRoot "bin\$sdkVersionName\x86")
        )
        include = @(
            (Join-Path $toolset.FullName "include"),
            (Join-Path $sdkRoot "Include\$sdkVersionName\ucrt"),
            (Join-Path $sdkRoot "Include\$sdkVersionName\shared"),
            (Join-Path $sdkRoot "Include\$sdkVersionName\um"),
            (Join-Path $sdkRoot "Include\$sdkVersionName\winrt")
        )
        lib = @(
            (Join-Path $toolset.FullName "lib\x86"),
            (Join-Path $sdkRoot "Lib\$sdkVersionName\ucrt\x86"),
            (Join-Path $sdkRoot "Lib\$sdkVersionName\um\x86")
        )
    }
}

function Invoke-NativeProcess {
    param(
        [string]$FilePath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$StandardOutputPath,
        [string]$StandardErrorPath,
        [System.Text.Encoding]$OutputEncoding = [System.Text.Encoding]::UTF8
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $Arguments
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = $OutputEncoding
    $startInfo.StandardErrorEncoding = $OutputEncoding
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Failed to start '$FilePath'." }
    $standardOutput = $process.StandardOutput.ReadToEndAsync()
    $standardError = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $standardOutput.Result | Set-Content -LiteralPath $StandardOutputPath -Encoding UTF8
    $standardError.Result | Set-Content -LiteralPath $StandardErrorPath -Encoding UTF8
    return $process.ExitCode
}

function Write-BuildMetadata {
    param([string]$ResolvedMSBuild, [datetime]$StartedAt, [int]$ExitCode)
    $metadata = [ordered]@{
        schemaVersion = 1
        configuration = $Configuration
        platform = $Platform
        startedAtUtc = $StartedAt.ToUniversalTime().ToString("o")
        finishedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        exitCode = $ExitCode
        succeeded = ($ExitCode -eq 0)
        msbuild = $ResolvedMSBuild
        solution = $solutionPath
        output = Join-Path $repoRoot "$Configuration\thprac.exe"
        consoleLog = $consoleLog
        errorLog = $errorLog
        helperLog = $helperLog
        helperErrorLog = $helperErrorLog
        diagnosticLog = $diagnosticLog
        binaryLog = $binaryLog
    }
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $latestPath -Encoding UTF8
}

$startedAt = Get-Date
$resolvedMSBuild = $null
$exitCode = 1
try {
    $resolvedMSBuild = Find-MSBuild -RequestedPath $MSBuildPath
    $cppEnvironment = Find-VisualCppEnvironment -ResolvedMSBuild $resolvedMSBuild
    $env:VSLANG = "1033"
    $env:PreferredUILang = "en-US"
    $nativeEncoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
    Write-Host "Repository:    $repoRoot"
    Write-Host "Configuration: $Configuration|$Platform"
    Write-Host "MSBuild:       $resolvedMSBuild"
    Write-Host "Logs:          $runLogRoot"

    # CI builds this generator separately; the vcxproj consumes but does not produce it.
    $env:Path = (@($cppEnvironment.path) + @($env:Path)) -join ";"
    $env:INCLUDE = (@($cppEnvironment.include) + @($env:INCLUDE)) -join ";"
    $env:LIB = (@($cppEnvironment.lib) + @($env:LIB)) -join ";"
    $helperArguments = '/Isrc\3rdparties\yyjson /nologo /EHsc /O2 /std:c++20 loc_json.cpp .\src\3rdParties\yyjson\yyjson.c /Fe:loc_json.exe'
    Push-Location (Join-Path $repoRoot "thprac")
    try {
        $helperExitCode = Invoke-NativeProcess -FilePath $cppEnvironment.cl -Arguments $helperArguments -WorkingDirectory (Get-Location).Path -StandardOutputPath $helperLog -StandardErrorPath $helperErrorLog -OutputEncoding $nativeEncoding
    }
    finally { Pop-Location }
    if ($helperExitCode -ne 0) {
        throw "loc_json.exe build failed with exit code $helperExitCode. See '$helperLog' and '$helperErrorLog'."
    }

    $targets = if ($Clean) { "Clean;Build" } else { "Restore;Build" }
    $arguments = @(
        $solutionPath, "/nologo", "/m", "/t:$targets",
        "/p:RestorePackagesConfig=true", "/p:Configuration=$Configuration", "/p:Platform=$Platform",
        "/bl:$binaryLog", "/fl", "/flp:LogFile=$diagnosticLog;Verbosity=diagnostic", "/verbosity:minimal"
    )
    $argumentLine = ($arguments | ForEach-Object { '"{0}"' -f ($_ -replace '"', '\"') }) -join " "
    $exitCode = Invoke-NativeProcess -FilePath $resolvedMSBuild -Arguments $argumentLine -WorkingDirectory $repoRoot -StandardOutputPath $consoleLog -StandardErrorPath $errorLog -OutputEncoding $nativeEncoding
    if (Test-Path -LiteralPath $consoleLog) { Get-Content -LiteralPath $consoleLog | Write-Host }
    if (Test-Path -LiteralPath $errorLog) {
        $errorText = Get-Content -LiteralPath $errorLog -Raw
        if (-not [string]::IsNullOrWhiteSpace($errorText)) { Write-Error $errorText -ErrorAction Continue }
    }
    if ($exitCode -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $repoRoot "$Configuration\thprac.exe"))) {
        $exitCode = 2
        Write-Error "MSBuild reported success, but '$Configuration\thprac.exe' was not produced." -ErrorAction Continue
    }
}
catch {
    $_ | Out-String | Tee-Object -FilePath $consoleLog -Append | Write-Error -ErrorAction Continue
    $exitCode = 1
}
finally {
    Write-BuildMetadata -ResolvedMSBuild $resolvedMSBuild -StartedAt $startedAt -ExitCode $exitCode
}

if ($exitCode -eq 0) {
    Write-Host "Build succeeded: $(Join-Path $repoRoot "$Configuration\thprac.exe")"
}
else {
    Write-Error "Build failed with exit code $exitCode. See '$consoleLog' and '$binaryLog'." -ErrorAction Continue
}
exit $exitCode
