<#
.SYNOPSIS
  Post-flash: ping target until first reply; prints elapsed seconds (计时 ping).

.DESCRIPTION
  Use after flash/reboot to see how long until the device answers ping. Default probe every 1s.
  Uses .NET ICMP (same family as ping.exe), not Test-Connection — Windows PS 5.1 lacks -TimeoutSeconds on Test-Connection and would always fail.
  `hiker_x9-minimal` / `minimal-baseline` 的 LAN 多为 192.168.1.1（上游默认）；`minimal` 无 dnsmasq 时本机可设静态 IP 再 ping。历史 `hiker-x9-minimal-defaults` 曾为 192.168.100.1。
  U-Boot / Web 刷机后无 SSH 时，用本脚本从 PC 计时首 ICMP；可选 `-ProbeTcpPort 80` 在 ping 通后再计到 Web 端口打开。

.PARAMETER Target
  IP or hostname (default 192.168.1.1, typical OpenWrt LAN).

.PARAMETER IntervalSeconds
  Seconds between probes (default 1).

.PARAMETER MaxWaitSeconds
  Stop after this many seconds with exit code 1 (default 0 = unlimited). Ctrl+C always stops.

.PARAMETER PingTimeoutMs
  Per-probe ICMP timeout in milliseconds (default 2000).

.PARAMETER ProbeTcpPort
  After first ICMP OK, keep same clock and wait until this TCP port accepts connections (e.g. 80). 0 = ICMP only.

.PARAMETER MaxWaitTcpSeconds
  Max seconds after ICMP OK to wait for TCP (0 = unlimited).

.PARAMETER TcpConnectTimeoutMs
  Per-attempt TCP connect timeout (ms).

.EXAMPLE
  .\scripts\ping-until-up.ps1
  .\scripts\ping-until-up.ps1 -Target 192.168.6.1 -MaxWaitSeconds 300
  .\scripts\ping-until-up.ps1 -Target 192.168.1.1 -ProbeTcpPort 80
#>
param(
    [string] $Target = "192.168.1.1",
    [double] $IntervalSeconds = 1.0,
    [int] $MaxWaitSeconds = 0,
    [int] $PingTimeoutMs = 2000,
    [int] $ProbeTcpPort = 0,
    [int] $MaxWaitTcpSeconds = 600,
    [int] $TcpConnectTimeoutMs = 2000
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

function Test-TcpPortOpen {
    param(
        [string] $HostOrIp,
        [int] $Port,
        [int] $ConnectTimeoutMs
    )
    if ($Port -le 0 -or $Port -gt 65535) { return $false }
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($HostOrIp, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($ConnectTimeoutMs)) {
            return $false
        }
        $client.EndConnect($iar)
        return $client.Connected
    } catch {
        return $false
    } finally {
        if ($null -ne $client) {
            try {
                if ($client.Connected) { $client.Close() }
            } catch { }
            $client.Dispose()
        }
    }
}

$start = [Diagnostics.Stopwatch]::StartNew()

$maxLabel = if ($MaxWaitSeconds -gt 0) { "${MaxWaitSeconds}s" } else { "unlimited" }
$tcpLabel = if ($ProbeTcpPort -gt 0) { " | then TCP port $ProbeTcpPort (connect timeout ${TcpConnectTimeoutMs}ms, max after ping ${MaxWaitTcpSeconds}s)" } else { "" }
Write-Host "Target: $Target | Interval: ${IntervalSeconds}s | Max wait: $maxLabel | ICMP timeout: ${PingTimeoutMs}ms$tcpLabel"
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
        $icmpSec = $elapsed.TotalSeconds
        Write-Host ("[{0,6:F1}s] Ping OK: {1}" -f $icmpSec, $Target)
        if ($ProbeTcpPort -le 0) {
            exit 0
        }
        $swTcp = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            $total = $start.Elapsed.TotalSeconds
            if ($MaxWaitTcpSeconds -gt 0 -and $swTcp.Elapsed.TotalSeconds -ge $MaxWaitTcpSeconds) {
                Write-Host ("[{0,6:F1}s] TCP {1} timeout after ICMP (waited {2:F1}s post-ping)." -f $total, $ProbeTcpPort, $swTcp.Elapsed.TotalSeconds)
                exit 1
            }
            if (Test-TcpPortOpen -HostOrIp $Target -Port $ProbeTcpPort -ConnectTimeoutMs $TcpConnectTimeoutMs) {
                $tcpTotal = $start.Elapsed.TotalSeconds
                $gap = $tcpTotal - $icmpSec
                Write-Host ("[{0,6:F1}s] TCP port {1} OK (same clock; {2:F1}s after ping OK)" -f $tcpTotal, $ProbeTcpPort, $gap)
                exit 0
            }
            Write-Host ("[{0,6:F1}s] TCP {1} not ready..." -f $total, $ProbeTcpPort)
            Start-Sleep -Seconds $IntervalSeconds
        }
    }

    Write-Host ("[{0,6:F1}s] No reply..." -f $elapsed.TotalSeconds)
    Start-Sleep -Seconds $IntervalSeconds
}
