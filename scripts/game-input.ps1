[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Up','Down','Left','Right','Z','X','C','A','S','D','V','Shift','Ctrl','Enter','Escape','Backspace','Tab','Space','R','F1','F11','F12')][string[]]$Keys,
    [ValidateRange(30,2000)][int]$HoldMs = 120,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$SessionId
)
. "$PSScriptRoot\debug-common.ps1"
$gameProcess = $null
$inputLock = $null
try {
    $dir = Get-SessionDirectory
    if (!$dir -or (Split-Path $dir -Leaf) -ne $SessionId) { throw 'Session changed; observe the new game before sending input.' }
    # Serialize with start/stop as well as other inputs, so identity stays current.
    $inputLock = [IO.File]::Open((Join-Path $DebugRoot 'control.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    if ((Get-SessionDirectory) -ne $dir) { throw 'Session changed while acquiring the lock.' }
    $state = Read-DebugJson (Join-Path $dir 'state.json')
    if ($state.phase -ne 'running' -or !$state.targetGame) { throw 'A running managed game session is required.' }
    $gameProcess = Get-OwnedProcess $state.game
    if (!$gameProcess) { throw 'Game identity check failed; no input sent.' }
    if ($Keys.Count -gt 4 -or ($Keys | Select-Object -Unique).Count -ne $Keys.Count) { throw 'Specify 1-4 distinct keys.' }
    $scanCodes = @{ Escape=0x01; Backspace=0x0e; Tab=0x0f; Enter=0x1c; Ctrl=0x1d; R=0x13; A=0x1e; S=0x1f; D=0x20; Shift=0x2a; Z=0x2c; X=0x2d; C=0x2e; V=0x2f; Space=0x39; F1=0x3b; F11=0x57; F12=0x58; Up=0x148; Left=0x14b; Right=0x14d; Down=0x150 }
    Add-Type -Path "$PSScriptRoot\GameInput.cs"
    [ushort[]]$scans = @($Keys | ForEach-Object { $scanCodes[$_] })
    [ThpracGameInput]::Press($gameProcess, $scans, $HoldMs)
    $entry = [ordered]@{ utc=[DateTime]::UtcNow.ToString('o'); session=$SessionId; pid=$gameProcess.Id; keys=$Keys; holdMs=$HoldMs; result='sent (verify on screen)' }
    ($entry | ConvertTo-Json -Compress) | Add-Content -LiteralPath (Join-Path $dir 'input.jsonl') -Encoding utf8
    $entry | ConvertTo-Json
} catch { Write-Error $_; exit 1 }
finally {
    if ($gameProcess) { $gameProcess.Dispose() }
    if ($inputLock) { $inputLock.Dispose() }
}
