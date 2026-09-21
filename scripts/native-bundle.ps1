[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Debug', 'Release')][string]$Configuration,
    [Parameter(Mandatory)][string]$Output
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$native = Join-Path $repo "x64\$Configuration"
# Keep this order in sync with thprac_native_bundle.h. IDs 100-110 are RCDATA.
$files = @(
    @('thprac_bridge64.exe', (Join-Path $native 'thprac_bridge64.exe')),
    @('thprac_th06nc.dll', (Join-Path $native 'thprac_th06nc.dll')),
    @('freetype.dll', (Join-Path $repo 'thprac\src\3rdParties\FreeType\win64\freetype.dll')),
    @('README_NC.md', (Join-Path $repo 'README_NC.md')),
    @('LICENCE', (Join-Path $repo 'LICENCE')),
    @('licenses/FreeType-LICENSE.txt', (Join-Path $repo 'thprac\src\3rdParties\FreeType\LICENSE.TXT')),
    @('licenses/FreeType-FTL.txt', (Join-Path $repo 'thprac\src\3rdParties\FreeType\FTL.TXT')),
    @('licenses/MinHook.txt', (Join-Path $repo 'thprac\src\3rdParties\MinHook\LICENSE.txt')),
    @('licenses/ImGui.txt', (Join-Path $repo 'thprac\src\3rdParties\ImGui\LICENSE.txt')),
    @('THIRD_PARTY_NOTICES.txt', (Join-Path $repo 'THIRD_PARTY_NC_NOTICES.txt'))
)
function Write-Changed([string]$Path, [string]$Text) {
    if (!(Test-Path -LiteralPath $Path) -or [IO.File]::ReadAllText($Path) -cne $Text) {
        [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
    }
}
$Output = [IO.Path]::GetFullPath($Output)
$outputDir = Split-Path $Output -Parent
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$manifest = [IO.MemoryStream]::new()
$sha = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($entry in $files) {
        $name = [Text.Encoding]::UTF8.GetBytes($entry[0] + [char]0)
        $manifest.Write($name, 0, $name.Length)
        $hash = $sha.ComputeHash([IO.File]::ReadAllBytes($entry[1]))
        $manifest.Write($hash, 0, $hash.Length)
    }
    $bundle = ([BitConverter]::ToString($sha.ComputeHash($manifest.ToArray()))).Replace('-', '').ToLowerInvariant()
} finally { $sha.Dispose(); $manifest.Dispose() }
$idPath = Join-Path $outputDir 'nc_bundle_id.txt'
Write-Changed $idPath $bundle
$lines = @('#include <windows.h>', '#pragma code_page(65001)', 'LANGUAGE 0, 0')
$paths = @($idPath) + @($files | ForEach-Object { $_[1] })
for ($i = 0; $i -lt $paths.Count; $i++) {
    $lines += ('{0} RCDATA "{1}"' -f (100 + $i), $paths[$i].Replace('\', '/'))
}
Write-Changed $Output (($lines -join "`r`n") + "`r`n")
Write-Output "New Classic bundle: $bundle"
