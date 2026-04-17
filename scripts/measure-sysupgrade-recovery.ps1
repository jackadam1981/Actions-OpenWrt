<#
.SYNOPSIS
  SCP 上传镜像并 SSH 执行 sysupgrade，计时「刷写到再次 ping 通」耗时（与 measure-reboot-recovery 同类）。

.DESCRIPTION
  默认在 sysupgrade 会话结束后等待 InitialGraceSeconds，再 ICMP 探测直至成功，并打印汇总报告。
  仅校验镜像用 -TestOnly；只上传刷写、不测时用 -NoWaitForPing。

.PARAMETER Image
  本机 sysupgrade 镜像路径（如 *-squashfs-sysupgrade.bin）。

.PARAMETER Target
  设备 LAN IP。

.PARAMETER RemotePath
  设备临时路径（默认 /tmp/sysupgrade.bin）。

.PARAMETER SshKey / SshUser
  SSH 认证。

.PARAMETER NoKeepConfig
  设备上 sysupgrade -n。

.PARAMETER TestOnly
  设备上 sysupgrade -T（不刷写；无恢复计时）。

.PARAMETER ForceImage
  设备上 sysupgrade -F（慎用）。

.PARAMETER NoWaitForPing
  不等待 ping、不输出恢复段报告（刷写后请自行用 ping-until-up.ps1）。

.PARAMETER InitialGraceSeconds
  SSH sysupgrade 返回后先等待再开始判定 ping 通（默认 30；避免尚未重启就误判）。

.PARAMETER IntervalSeconds
  恢复探测间隔（秒，支持小数）。

.PARAMETER PingTimeoutMs
  单次 ICMP 超时（毫秒）。

.PARAMETER MaxWaitSeconds
  宽限结束后最长等待 ping 通（秒，0 表示不限制）。

.PARAMETER SkipPingPrecheck
  跳过刷写前 ICMP 预检。

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.100.1 -Image D:\build\*-squashfs-sysupgrade.bin

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.100.1 -Image .\firmware.bin -NoKeepConfig -InitialGraceSeconds 45
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
    [switch] $NoWaitForPing,
    [int] $InitialGraceSeconds = 30,
    [double] $IntervalSeconds = 1.0,
    [int] $PingTimeoutMs = 2000,
    [int] $MaxWaitSeconds = 600,
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

$swTotal = [Diagnostics.Stopwatch]::StartNew()

$scpArgs = $sshBase + @(
    "-C",
    $imageFull,
    "${SshUser}@${Target}:${RemotePath}"
)

Write-Host "Uploading via SCP -> ${SshUser}@${Target}:${RemotePath}"
$swScp = [Diagnostics.Stopwatch]::StartNew()
& scp.exe @scpArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "SCP failed (exit $LASTEXITCODE)."
    exit 1
}
$durScp = $swScp.Elapsed
Write-Host ("Upload finished in {0:F1}s." -f $durScp.TotalSeconds)

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
$swSsh = [Diagnostics.Stopwatch]::StartNew()
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
$durSsh = $swSsh.Elapsed
Write-Host ("SSH/sysupgrade session: {0:F1}s (exit {1}; drop after flash is normal)" -f $durSsh.TotalSeconds, $sshExit)

if ($TestOnly) {
    if ($sshExit -ne 0) {
        Write-Error "sysupgrade -T reported failure (exit $sshExit)."
        exit 1
    }
    Write-Host "Test-only (-T) completed OK."
    exit 0
}

if ($NoWaitForPing) {
    Write-Host "NoWaitForPing: skipping recovery probe. Use scripts/ping-until-up.ps1 if needed."
    exit 0
}

Write-Host "Initial grace: waiting ${InitialGraceSeconds}s before ICMP success detection..."
Start-Sleep -Seconds $InitialGraceSeconds
$tAfterGrace = $swTotal.Elapsed

Write-Host "Probing ping recovery (max ${MaxWaitSeconds}s from end of grace, interval ${IntervalSeconds}s)..."
$swProbe = [Diagnostics.Stopwatch]::StartNew()
while ($true) {
    $probeElapsed = $swProbe.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $probeElapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Error "TIMEOUT: no ping within ${MaxWaitSeconds}s after grace."
        exit 1
    }
    if (Test-IcmpReachable -HostOrIp $Target -TimeoutMs $PingTimeoutMs) {
        break
    }
    Write-Host ("[{0,6:F1}s] waiting for ping..." -f $probeElapsed.TotalSeconds)
    $sleepMs = [int]([Math]::Max(50, [Math]::Round($IntervalSeconds * 1000.0)))
    Start-Sleep -Milliseconds $sleepMs
}

$durAfterGraceToUp = $swProbe.Elapsed.TotalSeconds
$durTotal = $swTotal.Elapsed.TotalSeconds

Write-Host ""
Write-Host "========== SYSUPGRADE RECOVERY REPORT =========="
Write-Host ("Target:                 {0}" -f $Target)
Write-Host ("Image:                  {0}" -f $imageFull)
Write-Host ("SSH key:                {0}" -f $SshKey)
Write-Host ("SCP upload:             {0:F1} s" -f $durScp.TotalSeconds)
Write-Host ("SSH sysupgrade:         {0:F1} s" -f $durSsh.TotalSeconds)
Write-Host ("Initial grace:          {0} s   (no success judgment during this window)" -f $InitialGraceSeconds)
Write-Host ("After grace -> ping OK: {0:F1} s" -f $durAfterGraceToUp)
Write-Host ("Total (SCP start -> ping OK): {0:F1} s" -f $durTotal)
Write-Host "================================================"

exit 0
