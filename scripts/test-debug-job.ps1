[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\debug-common.ps1"
if (!('ThpracDebugJob' -as [type])) { Add-Type -Path "$PSScriptRoot\DebugJob.cs" }
$testDir = Join-Path $DebugRoot ('job-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
$fixture = Join-Path $testDir 'loader fixture.ps1'
$received = Join-Path $testDir 'received.json'
@'
param([string]$OutputPath, [string]$Value)
@{value=$Value} | ConvertTo-Json | Set-Content -LiteralPath $OutputPath -Encoding utf8
$child = Start-Process -FilePath "$env:WINDIR\System32\ping.exe" -ArgumentList @('-n','30','127.0.0.1') -WindowStyle Hidden -PassThru
exit 0
'@ | Set-Content -LiteralPath $fixture -Encoding utf8
$job = $null
$child = $null
$unrelated = Start-Process -FilePath "$env:WINDIR\System32\ping.exe" -ArgumentList @('-n','30','127.0.0.1') -WindowStyle Hidden -PassThru
$null = $unrelated.Handle
try {
    $value = 'Unicode 東方, spaces, "quotes", trailing slash\'
    $shell = (Get-Process -Id $PID).Path
    $job = [ThpracDebugJob]::new($shell, [string[]]@('-NoProfile','-File',$fixture,$received,$value), $testDir)
    if (!$job.Root.WaitForExit(10000) -or $job.Root.ExitCode -ne 0) { throw 'Fixture loader did not exit successfully.' }
    if ((Read-DebugJson $received).value -cne $value) { throw 'Unicode/quote argument round trip failed.' }
    $members = @($job.Processes())
    foreach ($member in $members) {
        if ((Split-Path $member.Path -Leaf) -ieq 'ping.exe' -and !$child) { $child = $member }
        else { $member.Dispose() }
    }
    if (!$child) { throw 'Expected a ping child after loader exit.' }
    if ($child.Id -eq $unrelated.Id -or (Split-Path $child.Path -Leaf) -ine 'ping.exe') { throw 'Wrong child selected.' }
    $job.Dispose()
    $job = $null
    if (!$child.WaitForExit(5000)) { throw 'Job close did not clean up child.' }
    $unrelated.Refresh()
    if ($unrelated.HasExited) { throw 'An unrelated same-name process was terminated.' }
    $record = Get-ProcessRecord $unrelated $unrelated.Path
    $record.startedUtc = $unrelated.StartTime.AddSeconds(-1).ToUniversalTime().ToString('o')
    if (Get-OwnedProcess $record) { throw 'Stale PID identity was accepted.' }
    Write-Output 'PASS: Unicode/quotes; exited loader; child membership; job cleanup; unrelated same-name process; stale PID rejection.'
} finally {
    if ($job) { $job.Dispose() }
    if ($child) { $child.Dispose() }
    Stop-OwnedProcess $unrelated
    $unrelated.Dispose()
}
