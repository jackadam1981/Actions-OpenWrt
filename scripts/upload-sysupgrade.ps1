<#
.SYNOPSIS
  SCP 上传固件到设备，SSH 执行 sysupgrade（OpenWrt 在线升级 / 刷写）。

.DESCRIPTION
  默认：上传到 /tmp/sysupgrade.bin，执行 sysupgrade -v（保留配置）。
  可选 -TestOnly 仅校验镜像；-NoKeepConfig 对应 sysupgrade -n。
  可选 -WaitForPing：下发 sysupgrade 后在本机 ICMP 等到再次通（刷机后常用）。

.PARAMETER Image
  本机 sysupgrade.bin（或其它 sysupgrade 接受的镜像）路径。

.PARAMETER Target
  设备 LAN IP。

.PARAMETER RemotePath
  设备上临时路径（默认 /tmp/sysupgrade.bin）。

.PARAMETER SshKey
  SSH 私钥路径。

.PARAMETER SshUser
  SSH 用户名（默认 root）。

.PARAMETER NoKeepConfig
  传 -n，不保留配置刷写。

.PARAMETER TestOnly
  传 -T，只校验镜像，不实际刷写。

.PARAMETER ForceImage
  传 -F，忽略部分校验（慎用，仅当设备端 sysupgrade 支持且你清楚风险）。

.PARAMETER WaitForPing
  sysupgrade 返回后在本机循环 ping，直到通或超时。

.PARAMETER InitialGraceSeconds
  与 measure-reboot-recovery 类似：发完 sysupgrade 后先等待再开始 ping（默认 20）。

.PARAMETER PingIntervalSeconds
  WaitForPing 时探测间隔。

.PARAMETER MaxWaitPingSeconds
  WaitForPing 最长等待（默认 600，0 表示不限制）。

.PARAMETER PingTimeoutMs
  单次 ICMP 超时（毫秒）。

.EXAMPLE
  .\scripts\upload-sysupgrade.ps1 -Target 192.168.100.1 -Image D:\build\openwrt-ramips-rt305x-hiker_x9-minimal-squashfs-sysupgrade.bin

.EXAMPLE
  .\scripts\upload-sysupgrade.ps1 -Target 192.168.100.1 -Image .\firmware.bin -NoKeepConfig -WaitForPing -InitialGraceSeconds 30
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $Image,
    [string] $Target = "192.168.1.1",
    [string] $RemotePath = "/tmp/sysupgrade.bin",
    [string] $SshKey = $(Join-Path $env:USERPROFILE ".ssh\hiker_x9_cursor"),
    [string] $SshUser = "root",
    [switch] $NoKeepConfig,
    [switch] $TestOnly,
    [switch] $ForceImage,
    [switch] $WaitForPing,
    [int] $InitialGraceSeconds = 20,
    [double] $PingIntervalSeconds = 1.0,
    [int] $MaxWaitPingSeconds = 600,
    [int] $PingTimeoutMs = 2000,
    [switch] $SkipPingPrecheck
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

$imageFull = (Resolve-Path -LiteralPath $Image -ErrorAction SilentlyContinue)
if ($null -eq $imageFull) {
    Write-Error "Image file not found: $Image"
    exit 3
}
$imageFull = $imageFull.Path

if (-not $SkipPingPrecheck) {
    Write-Host "Pre-check: ping $Target ..."
    $preOk = $false
    for ($i = 0; $i -lt 10; $i++) {
        if (Test-IcmpReachable -HostOrIp $Target -TimeoutMs $PingTimeoutMs) { $preOk = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $preOk) {
        Write-Error "Target not reachable. Check IP / cable / firewall, or use -SkipPingPrecheck."
        exit 4
    }
    Write-Host "Pre-check OK."
}

$sshBase = @(
    "-i", $SshKey,
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ConnectTimeout=30",
    "-o", "ConnectionAttempts=1"
)

$scpArgs = $sshBase + @(
    "-C",
    $imageFull,
    "${SshUser}@${Target}:${RemotePath}"
)

Write-Host "Uploading via SCP -> ${SshUser}@${Target}:${RemotePath}"
& scp.exe @scpArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "SCP failed (exit $LASTEXITCODE)."
    exit 1
}
Write-Host "Upload finished."

$remoteArgs = @("-v")
if ($TestOnly) { $remoteArgs += "-T" }
if ($NoKeepConfig) { $remoteArgs += "-n" }
if ($ForceImage) { $remoteArgs += "-F" }
$remoteArgs += $RemotePath
$remoteCmd = "sysupgrade " + ($remoteArgs -join " ")

$sshArgs = $sshBase + @(
    "${SshUser}@${Target}",
    $remoteCmd
)

Write-Host "Running on device: $remoteCmd"
$sw = [Diagnostics.Stopwatch]::StartNew()
$sshOut = $null
try {
    $sshOut = & ssh.exe @sshArgs 2>&1
} catch {
    Write-Host "(SSH session ended: $($_.Exception.Message))"
}
if ($null -ne $sshOut) {
    $sshOut | ForEach-Object { Write-Host $_ }
}
$sshExit = $LASTEXITCODE
$sshElapsed = $sw.Elapsed
Write-Host ("SSH/sysupgrade session elapsed: {0:F1}s (connection drop after flash is normal)" -f $sshElapsed.TotalSeconds)

if ($TestOnly) {
    if ($sshExit -ne 0) {
        Write-Error "sysupgrade -T reported failure (exit $sshExit)."
        exit 1
    }
    Write-Host "Test-only (-T) completed OK."
    exit 0
}

if (-not $WaitForPing) {
    Write-Host "Done. Device may be rebooting; use scripts/ping-until-up.ps1 or -WaitForPing to wait for ICMP."
    exit 0
}

Write-Host "WaitForPing: initial grace ${InitialGraceSeconds}s..."
Start-Sleep -Seconds $InitialGraceSeconds

$pingSw = [Diagnostics.Stopwatch]::StartNew()
while ($true) {
    $elapsed = $pingSw.Elapsed
    if ($MaxWaitPingSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitPingSeconds) {
        Write-Error "WaitForPing timeout after ${MaxWaitPingSeconds}s."
        exit 1
    }
    if (Test-IcmpReachable -HostOrIp $Target -TimeoutMs $PingTimeoutMs) {
        $totalWait = $pingSw.Elapsed.TotalSeconds
        Write-Host ("Ping OK after {0:F1}s (after initial grace)." -f $totalWait)
        exit 0
    }
    Write-Host ("[{0,6:F1}s] waiting for ping..." -f $elapsed.TotalSeconds)
    $sleepMs = [int]([Math]::Max(50, [Math]::Round($PingIntervalSeconds * 1000.0)))
    Start-Sleep -Milliseconds $sleepMs
}
