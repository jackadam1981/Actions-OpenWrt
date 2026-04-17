<#
.SYNOPSIS
  通过 SSH 下发 reboot，本地 ICMP 探测，汇报「重启到再次 ping 通」耗时。

.DESCRIPTION
  1) 先确认当前能 ping 通；2) SSH 执行 reboot；3) 等待 InitialGraceSeconds（默认 30s，因设备未必立刻重启）；4) 再开始 ICMP 判定连通。
  汇报：SSH 下发到首次 ping 通总时长；宽限期后至 ping 通时长；若宽限后曾观测掉线再恢复，则汇报掉线→恢复。

.PARAMETER Target
  设备 LAN IP（baseline 多为 192.168.1.1；minimal 多为 192.168.100.1）。

.PARAMETER SshKey
  SSH 私钥路径。

.PARAMETER SshUser
  SSH 用户名（默认 root）。

.PARAMETER IntervalSeconds
  ping 探测间隔（秒）。

.PARAMETER PingTimeoutMs
  单次 ICMP 超时（毫秒）。

.PARAMETER MaxWaitSeconds
  reboot 后最长等待恢复（秒），超时退出码 1。

.PARAMETER MinDownProbes
  宽限结束后，判定「已掉线」所需的连续 ping 失败次数。

.PARAMETER InitialGraceSeconds
  SSH 发出 reboot 后，先等待再开始 ICMP 判定（默认 30；发令后设备常延迟才真正重启）。

.EXAMPLE
  .\scripts\measure-reboot-recovery.ps1 -Target 192.168.1.1 -SshKey "$env:USERPROFILE\.ssh\hiker_x9_cursor"
#>
param(
    [string] $Target = "192.168.1.1",
    [string] $SshKey = $(Join-Path $env:USERPROFILE ".ssh\hiker_x9_cursor"),
    [string] $SshUser = "root",
    [double] $IntervalSeconds = 0.5,
    [int] $PingTimeoutMs = 1000,
    [int] $MaxWaitSeconds = 600,
    [int] $MinDownProbes = 2,
    [int] $InitialGraceSeconds = 30
)

Set-StrictMode -Version 3
$ErrorActionPreference = "Continue"

function Test-IcmpReachable {
    param([string] $HostOrIp, [int] $TimeoutMs)
    $pinger = $null
    try {
        $pinger = New-Object System.Net.NetworkInformation.Ping
        $reply = $pinger.Send($HostOrIp, $TimeoutMs)
        return ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
    } catch {
        return $false
    } finally {
        if ($null -ne $pinger) { $pinger.Dispose() }
    }
}

if (-not (Test-Path -LiteralPath $SshKey)) {
    Write-Error "SSH key not found: $SshKey"
    exit 2
}

Write-Host "Pre-check: ping $Target ..."
$preOk = $false
for ($i = 0; $i -lt 10; $i++) {
    if (Test-IcmpReachable -HostOrIp $Target -TimeoutMs $PingTimeoutMs) { $preOk = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $preOk) {
    Write-Error "Target not reachable before reboot. Check IP / cable / firewall."
    exit 3
}
Write-Host "Pre-check OK."

$sshArgs = @(
    "-i", $SshKey,
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ConnectTimeout=10",
    "-o", "ConnectionAttempts=1",
    "${SshUser}@${Target}",
    "sync; reboot"
)

Write-Host "Issuing reboot via SSH..."
$swTotal = [Diagnostics.Stopwatch]::StartNew()
try {
    & ssh.exe @sshArgs 2>&1 | Out-Null
} catch {
    # 连接被对端 reset 为常态
}
$tAfterSsh = $swTotal.Elapsed

Write-Host "Initial grace: waiting ${InitialGraceSeconds}s before ICMP success detection (reboot may be delayed)..."
Start-Sleep -Seconds $InitialGraceSeconds
$tGraceEnd = $swTotal.Elapsed
$probeStartSec = $tGraceEnd.TotalSeconds + 0.5

$downProbes = 0
$firstDownAt = $null
$firstUpAfterDownAt = $null

Write-Host "Probing ping recovery (max ${MaxWaitSeconds}s from SSH, interval ${IntervalSeconds}s)..."
while ($true) {
    $elapsed = $swTotal.Elapsed
    if ($elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("TIMEOUT after {0:F1}s total." -f $elapsed.TotalSeconds)
        if ($null -eq $firstDownAt) {
            Write-Host "Hint: ICMP never went down after grace. Reboot may have finished during grace — try larger -InitialGraceSeconds, or device did not reboot."
        }
        exit 1
    }

    $ok = Test-IcmpReachable -HostOrIp $Target -TimeoutMs $PingTimeoutMs
    if ($ok) {
        if ($null -ne $firstDownAt) {
            $firstUpAfterDownAt = $elapsed
            break
        }
        $downProbes = 0
    } else {
        if ($elapsed.TotalSeconds -ge $probeStartSec) {
            $downProbes++
            if ($downProbes -ge $MinDownProbes -and $null -eq $firstDownAt) {
                $firstDownAt = $elapsed
                Write-Host ("[{0,6:F1}s] Link appears down (ICMP failed x{1})." -f $elapsed.TotalSeconds, $downProbes)
            }
        }
    }

    $sleepMs = [int]([Math]::Max(50, [Math]::Round($IntervalSeconds * 1000.0)))
    Start-Sleep -Milliseconds $sleepMs
}

$totalSec = $swTotal.Elapsed.TotalSeconds
$postGraceToUp = ($firstUpAfterDownAt - $tGraceEnd).TotalSeconds
Write-Host ""
Write-Host "========== REBOOT RECOVERY REPORT =========="
Write-Host ("Target:              {0}" -f $Target)
Write-Host ("SSH key:             {0}" -f $SshKey)
Write-Host ("Initial grace:       {0} s   (no success judgment during this window)" -f $InitialGraceSeconds)
Write-Host ("Total (SSH->ping OK): {0:F1} s   (from SSH reboot to first ping OK after grace)" -f $totalSec)
Write-Host ("After grace->ping OK: {0:F1} s   (from end of grace to first ping OK)" -f $postGraceToUp)
if ($null -ne $firstDownAt -and $null -ne $firstUpAfterDownAt) {
    $pure = ($firstUpAfterDownAt - $firstDownAt).TotalSeconds
    Write-Host ("Down -> up:          {0:F1} s   (first sustained ICMP fail after grace -> first ICMP OK)" -f $pure)
    Write-Host ("First ICMP down at:  {0:F1} s after SSH reboot" -f $firstDownAt.TotalSeconds)
}
Write-Host "============================================"

exit 0
