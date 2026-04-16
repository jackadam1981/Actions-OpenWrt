<#
.SYNOPSIS
  Post-flash: ping target until first reply; prints elapsed seconds (计时 ping).

.DESCRIPTION
  Use after flash/reboot to see how long until the device answers ping. Default probe every 1s.

.PARAMETER Target
  IP or hostname (default 192.168.1.1, typical OpenWrt LAN).

.PARAMETER IntervalSeconds
  Seconds between probes (default 1).

.PARAMETER MaxWaitSeconds
  Stop after this many seconds with exit code 1 (default 0 = unlimited). Ctrl+C always stops.

.EXAMPLE
  .\scripts\ping-until-up.ps1
  .\scripts\ping-until-up.ps1 -Target 192.168.6.1 -MaxWaitSeconds 300
#>
param(
    [string] $Target = "192.168.1.1",
    [double] $IntervalSeconds = 1.0,
    [int] $MaxWaitSeconds = 0
)

$ErrorActionPreference = "Stop"
$start = [Diagnostics.Stopwatch]::StartNew()

$maxLabel = if ($MaxWaitSeconds -gt 0) { "${MaxWaitSeconds}s" } else { "unlimited" }
Write-Host "Target: $Target | Interval: ${IntervalSeconds}s | Max wait: $maxLabel"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

while ($true) {
    $elapsed = $start.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("[{0,6:F1}s] Timeout, still no ping reply." -f $elapsed.TotalSeconds)
        exit 1
    }

    try {
        $ok = Test-Connection -ComputerName $Target -Count 1 -Quiet -TimeoutSeconds 2
    } catch {
        $ok = $false
    }

    if ($ok) {
        Write-Host ("[{0,6:F1}s] Ping OK: {1}" -f $elapsed.TotalSeconds, $Target)
        exit 0
    }

    Write-Host ("[{0,6:F1}s] No reply..." -f $elapsed.TotalSeconds)
    Start-Sleep -Seconds $IntervalSeconds
}
