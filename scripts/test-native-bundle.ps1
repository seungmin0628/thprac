[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $repo "$Configuration\thprac.exe"
# Load as data only: never execute the launcher, module or bridge during this check.
if (!('NativeBundleReader' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeBundleReader {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr LoadLibraryExW(string path, IntPtr file, uint flags);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    static extern IntPtr FindResourceW(IntPtr module, IntPtr name, IntPtr type);
    [DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr resource);
    [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll")] public static extern bool FreeLibrary(IntPtr module);
    public static byte[] Read(IntPtr module, int id) {
        var resource = FindResourceW(module, (IntPtr)id, (IntPtr)10);
        if (resource == IntPtr.Zero) throw new Exception("Missing RCDATA " + id);
        var bytes = new byte[SizeofResource(module, resource)];
        Marshal.Copy(LockResource(LoadResource(module, resource)), bytes, 0, bytes.Length);
        return bytes;
    }
}
'@
}
function Assert-Machine([byte[]]$Bytes, [int]$Machine) {
    $pe = [BitConverter]::ToInt32($Bytes, 60)
    if ([BitConverter]::ToUInt32($Bytes, $pe) -ne 0x4550 -or
        [BitConverter]::ToUInt16($Bytes, $pe + 4) -ne $Machine) { throw 'Incorrect PE architecture' }
}
Assert-Machine ([IO.File]::ReadAllBytes($exe)) 0x14c
$module = [NativeBundleReader]::LoadLibraryExW($exe, [IntPtr]::Zero, 0x22)
if ($module -eq [IntPtr]::Zero) { throw "Cannot read EXE resources: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
$sha = [Security.Cryptography.SHA256]::Create()
$manifest = [IO.MemoryStream]::new()
try {
    $names = @('thprac_bridge64.exe', 'thprac_th06nc.dll', 'freetype.dll', 'README_NC.md', 'LICENCE',
        'licenses/FreeType-LICENSE.txt', 'licenses/FreeType-FTL.txt', 'licenses/MinHook.txt',
        'licenses/ImGui.txt', 'THIRD_PARTY_NOTICES.txt')
    for ($i = 0; $i -lt $names.Count; $i++) {
        $bytes = [NativeBundleReader]::Read($module, 101 + $i)
        if (!$bytes.Length) { throw "Empty resource: $($names[$i])" }
        if ($i -lt 3) {
            Assert-Machine $bytes 0x8664
            $path = if ($i -lt 2) { Join-Path $repo "x64\$Configuration\$($names[$i])" }
                    else { Join-Path $repo 'thprac\src\3rdParties\FreeType\win64\freetype.dll' }
            $actual = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
            if ($actual -ne (Get-FileHash -LiteralPath $path).Hash) { throw "Stale embedded binary: $($names[$i])" }
        }
        $name = [Text.Encoding]::UTF8.GetBytes($names[$i] + [char]0)
        $manifest.Write($name, 0, $name.Length)
        $hash = $sha.ComputeHash($bytes)
        $manifest.Write($hash, 0, $hash.Length)
        Write-Output "PASS resource $($names[$i]) ($($bytes.Length) bytes)"
    }
    $expected = [Text.Encoding]::ASCII.GetString([NativeBundleReader]::Read($module, 100))
    $actual = [BitConverter]::ToString($sha.ComputeHash($manifest.ToArray())).Replace('-', '').ToLowerInvariant()
    if ($actual -cne $expected) { throw 'Bundle ID does not match embedded content' }
    Write-Output "PASS $Configuration single-EXE bundle $actual"
} finally {
    $manifest.Dispose(); $sha.Dispose()
    [void][NativeBundleReader]::FreeLibrary($module)
}
