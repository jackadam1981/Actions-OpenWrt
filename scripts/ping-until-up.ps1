<#
.SYNOPSIS
  Post-flash: ping target until first reply; prints elapsed seconds (计时 ping).

.DESCRIPTION
  Use after flash/reboot to see how long until the device answers ping. Default probe every 1s.
  Uses .NET ICMP (same family as ping.exe), not Test-Connection — Windows PS 5.1 lacks -TimeoutSeconds on Test-Connection and would always fail.
  Hiker minimal 固件 LAN 常为 192.168.100.1；baseline_only（hiker_x9-minimal-baseline）无 hiker defaults，LAN 多为 192.168.1.1，通常有 DHCP（上游默认包）。

.PARAMETER Target
  IP or hostname (default 192.168.1.1, typical OpenWrt LAN).

.PARAMETER IntervalSeconds
  Seconds between probes (default 1).

.PARAMETER MaxWaitSeconds
  Stop after this many seconds with exit code 1 (default 0 = unlimited). Ctrl+C always stops.

.PARAMETER PingTimeoutMs
  Per-probe ICMP timeout in milliseconds (default 2000).

.EXAMPLE
  .\scripts\ping-until-up.ps1
  .\scripts\ping-until-up.ps1 -Target 192.168.6.1 -MaxWaitSeconds 300
#>
param(
    [string] $Target = "192.168.1.1",
    [double] $IntervalSeconds = 1.0,
    [int] $MaxWaitSeconds = 0,
    [int] $PingTimeoutMs = 2000
)

function Test-IcmpReachable {
    param(
        [string] $HostOrIp,
        [int] $TimeoutMs
    )
    $pinger = $null
    try {
        $pinger = New-Object System.Net.NetworkInformation.Ping
        $reply = $pinger.Send($HostOrIp, $TimeoutMs)
        return ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
    } catch {
        return $false
    } finally {
        if ($null -ne $pinger) {
            $pinger.Dispose()
        }
    }
}

$start = [Diagnostics.Stopwatch]::StartNew()

$maxLabel = if ($MaxWaitSeconds -gt 0) { "${MaxWaitSeconds}s" } else { "unlimited" }
Write-Host "Target: $Target | Interval: ${IntervalSeconds}s | Max wait: $maxLabel | ICMP timeout: ${PingTimeoutMs}ms"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

while ($true) {
    $elapsed = $start.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("[{0,6:F1}s] Timeout, still no ping reply." -f $elapsed.TotalSeconds)
        exit 1
    }

    $ok = Test-IcmpReachable -HostOrIp $Target -TimeoutMs $PingTimeoutMs

    if ($ok) {
        Write-Host ("[{0,6:F1}s] Ping OK: {1}" -f $elapsed.TotalSeconds, $Target)
        exit 0
    }

    Write-Host ("[{0,6:F1}s] No reply..." -f $elapsed.TotalSeconds)
    Start-Sleep -Seconds $IntervalSeconds
}
