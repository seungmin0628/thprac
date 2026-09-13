[CmdletBinding()]
param([string]$MSBuildPath, [switch]$Clean)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$arguments = @{ Configuration = "Debug"; Platform = "x86"; Clean = $Clean }
if ($MSBuildPath) { $arguments.MSBuildPath = $MSBuildPath }
& (Join-Path $scriptDir "build.ps1") @arguments
exit $LASTEXITCODE
