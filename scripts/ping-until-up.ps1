<#
.SYNOPSIS
  刷机后计时：循环 ping 目标，直到首次成功，输出已等待秒数。

.DESCRIPTION
  用于观察路由器/开发板重启后多久能 ping 通。默认每 1 秒探测一次，打印当前已耗时。

.PARAMETER Target
  目标 IP 或主机名（默认 192.168.1.1，常见 OpenWrt LAN）。

.PARAMETER IntervalSeconds
  两次探测之间的间隔秒数（默认 1）。

.PARAMETER MaxWaitSeconds
  最长等待秒数，超时退出码 1（默认 0 表示不限制，可用 Ctrl+C 结束）。

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

Write-Host "目标: $Target | 间隔: ${IntervalSeconds}s | 最长等待: $(if ($MaxWaitSeconds -gt 0) { "${MaxWaitSeconds}s" } else { '无限制' })"
Write-Host "按 Ctrl+C 可随时停止。"
Write-Host ""

while ($true) {
    $elapsed = $start.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("[{0,6:F1}s] 超时仍未 ping 通。" -f $elapsed.TotalSeconds)
        exit 1
    }

    try {
        $ok = Test-Connection -ComputerName $Target -Count 1 -Quiet -TimeoutSeconds 2
    } catch {
        $ok = $false
    }

    if ($ok) {
        Write-Host ("[{0,6:F1}s] 已 ping 通: {1}" -f $elapsed.TotalSeconds, $Target)
        exit 0
    }

    Write-Host ("[{0,6:F1}s] 无响应..." -f $elapsed.TotalSeconds)
    Start-Sleep -Seconds $IntervalSeconds
}
