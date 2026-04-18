<#
.SYNOPSIS
  SCP 上传镜像并 SSH 执行 sysupgrade，计时「刷写到再次 ping 通」耗时（与 measure-reboot-recovery 同类）。

.DESCRIPTION
  sysupgrade 会话结束（SSH 常断开）后先等待 InitialGraceSeconds：此窗口**不表示** NAND 刷写已完成，仅避免立刻用 ICMP 误判。
  宽限结束后与 measure-reboot-recovery 相同：须先观测连续 MinDownProbes 次 ICMP 失败（掉线），再等到 ping 通，才记为「可 ping 恢复」。ICMP 恢复仍**不等于**镜像写入完成，实机请以指示灯等为准。
  可选 -ProbeTcpPortAfterPing 80：在 ICMP 恢复后再测 TCP 80（LuCI/uHTTPd 常晚于 ping）。
  仅校验镜像用 -TestOnly；只上传刷写、不测时用 -NoWaitForPing。

.PARAMETER Image
  本机 sysupgrade 镜像路径（如 *-squashfs-sysupgrade.bin）。

.PARAMETER Target
  设备 LAN IP。

.PARAMETER RemotePath
  设备临时路径（默认 /tmp/sysupgrade.bin）。

.PARAMETER SshKey / SshUser
  SSH 认证（OpenSSH 时用 -i 私钥；需 BatchMode，空密码不可用）。

.PARAMETER PlinkNoPassword
  使用 PuTTY 的 pscp/plink 非交互登录。PuTTY 0.78+ 已弃用 -pw，脚本用 -pwfile（空密码为仅含换行的一行）。batch 模式需信任主机密钥：请传 -PlinkHostKey（首次失败时日志里的 SHA256:...）。

.PARAMETER PlinkHostKey
  传给 pscp/plink 的 -hostkey（例如 SHA256:xxxx）。PlinkNoPassword + -batch 时未缓存主机密钥会失败。

.PARAMETER PuttyDirectory
  含 pscp.exe、plink.exe 的目录（优先查找）。默认 D:\\MyProgram\\putty；其它机器可传空字符串 "" 仅用 PATH / Program Files。

.PARAMETER NoKeepConfig
  设备上 sysupgrade -n。

.PARAMETER TestOnly
  设备上 sysupgrade -T（不刷写；无恢复计时）。

.PARAMETER ForceImage
  设备上 sysupgrade -F（慎用）。

.PARAMETER NoWaitForPing
  不等待 ping、不输出恢复段报告（刷写后请自行用 ping-until-up.ps1）。

.PARAMETER InitialGraceSeconds
  SSH/sysupgrade 断线后先等待再开始「掉线→恢复」判定（默认 30）。**不是**「再等 30 秒刷机就完成了」。

.PARAMETER MinDownProbes
  宽限结束后，判定「已掉线」所需的连续 ping 失败次数（默认 2）。

.PARAMETER IntervalSeconds
  恢复探测间隔（秒，支持小数）。

.PARAMETER PingTimeoutMs
  单次 ICMP 超时（毫秒）。

.PARAMETER MaxWaitSeconds
  自 SCP 开始计时的总预算（秒）；超时仍未在宽限后观测掉线再 ping 通则失败（0 表示不限制）。

.PARAMETER SkipPingPrecheck
  跳过刷写前 ICMP 预检。

.PARAMETER LegacySshRsaHostKey
  为 ssh/scp 追加 HostkeyAlgorithms/PubkeyAcceptedAlgorithms 的 +ssh-rsa（旧 Dropbear / OEM 仅 RSA 主机密钥）。

.PARAMETER ScpLegacyProtocol
  为 scp 追加 -O，走旧 SCP 协议（无 /usr/libexec/sftp-server 的 Chaos Calmer 等）。

.PARAMETER NoSshIdentity
  不传 -i 私钥、不用 BatchMode=yes，依赖 ssh 默认（如空密码 root 或 agent）。与 -LegacySshRsaHostKey 常一起用于 OEM。

.PARAMETER RecoveryTargets
  刷机后用于「恢复探测」的 LAN 地址，逗号分隔（如 192.168.1.1）。空则与 -Target 相同。典型：SSH 连 192.168.168.1，刷完新系统在 192.168.1.1。

.PARAMETER DownDetectTarget
  判定「已掉线」时 ping 的地址；默认同 -Target。与 -RecoveryTargets 不同时，先等本地址连续失败再等恢复地址任一 ping 通。

.PARAMETER ProbeTcpPortAfterPing
  大于 0 时，在「掉线后再 ping 通」之后继续探测该 TCP 端口（常用 80 = HTTP）。0 表示不测。

.PARAMETER MaxWaitTcpSeconds
  ICMP 已恢复后，等待 TCP 端口打开的最长时间（秒，0 不限制）。

.PARAMETER TcpConnectTimeoutMs
  单次 TCP 连接尝试超时（毫秒）。

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.100.1 -Image D:\build\*-squashfs-sysupgrade.bin

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.100.1 -Image .\firmware.bin -NoKeepConfig -InitialGraceSeconds 45

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.1.1 -Image .\Firmware\sysupgrade.bin -PlinkNoPassword -PlinkHostKey "SHA256:YOUR_FINGERPRINT"

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.168.1 -Image .\Firmware\*.bin -RecoveryTargets 192.168.1.1 -LegacySshRsaHostKey -ScpLegacyProtocol -NoSshIdentity -NoKeepConfig -ForceImage -ProbeTcpPortAfterPing 80
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $Image,
    [string] $Target = "192.168.1.1",
    [string] $RemotePath = "/tmp/sysupgrade.bin",
    [string] $SshKey = $(Join-Path $env:USERPROFILE ".ssh\hiker_x9_cursor"),
    [string] $SshUser = "root",
    [switch] $PlinkNoPassword,
    [string] $PlinkHostKey = "",
    [string] $PuttyDirectory = "D:\MyProgram\putty",
    [switch] $NoKeepConfig,
    [switch] $TestOnly,
    [switch] $ForceImage,
    [switch] $NoWaitForPing,
    [int] $InitialGraceSeconds = 30,
    [double] $IntervalSeconds = 1.0,
    [int] $PingTimeoutMs = 2000,
    [int] $MaxWaitSeconds = 600,
    [int] $MinDownProbes = 2,
    [int] $ProbeTcpPortAfterPing = 0,
    [int] $MaxWaitTcpSeconds = 600,
    [int] $TcpConnectTimeoutMs = 2000,
    [switch] $SkipPingPrecheck,
    [switch] $LegacySshRsaHostKey,
    [switch] $ScpLegacyProtocol,
    [switch] $NoSshIdentity,
    [string] $RecoveryTargets = "",
    [string] $DownDetectTarget = ""
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

function Test-IcmpAnyReachable {
    param(
        [string[]] $Hosts,
        [int] $TimeoutMs
    )
    foreach ($h in $Hosts) {
        if ([string]::IsNullOrWhiteSpace($h)) { continue }
        if (Test-IcmpReachable -HostOrIp $h.Trim() -TimeoutMs $TimeoutMs) { return $true }
    }
    return $false
}

function Test-TcpAnyOpen {
    param(
        [string[]] $Hosts,
        [int] $Port,
        [int] $ConnectTimeoutMs
    )
    foreach ($h in $Hosts) {
        if ([string]::IsNullOrWhiteSpace($h)) { continue }
        if (Test-TcpPortOpen -HostOrIp $h.Trim() -Port $Port -ConnectTimeoutMs $ConnectTimeoutMs) { return $true }
    }
    return $false
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

function Find-PuttyTool {
    param(
        [Parameter(Mandatory = $true)][string] $ExeName,
        [string] $PreferredDirectory = ""
    )
    if (-not [string]::IsNullOrWhiteSpace($PreferredDirectory)) {
        $d = $PreferredDirectory.Trim().TrimEnd('\', '/')
        if ($d.Length -gt 0) {
            $p = Join-Path $d $ExeName
            if (Test-Path -LiteralPath $p) {
                return (Resolve-Path -LiteralPath $p).Path
            }
        }
    }
    $cmd = Get-Command $ExeName -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and $cmd.Source) { return $cmd.Source }
    foreach ($dir in @(
            (Join-Path $env:ProgramFiles "PuTTY"),
            (Join-Path ${env:ProgramFiles(x86)} "PuTTY")
        )) {
        $p = Join-Path $dir $ExeName
        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
}

$plinkExe = $null
$pscpExe = $null
$plinkPwFile = $null
if ($PlinkNoPassword) {
    $pscpExe = Find-PuttyTool "pscp.exe" $PuttyDirectory
    $plinkExe = Find-PuttyTool "plink.exe" $PuttyDirectory
    if ($null -eq $pscpExe -or $null -eq $plinkExe) {
        Write-Error "PlinkNoPassword requires pscp.exe and plink.exe. Tried -PuttyDirectory '$PuttyDirectory', then PATH and Program Files\PuTTY. pscp=$pscpExe plink=$plinkExe"
        exit 2
    }
} elseif (-not $NoSshIdentity -and -not (Test-Path -LiteralPath $SshKey)) {
    Write-Error "SSH key not found: $SshKey (use -NoSshIdentity for root empty password / agent, or -PlinkNoPassword for PuTTY)"
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

$sshBase = if ($PlinkNoPassword) {
    @()
} elseif ($NoSshIdentity) {
    @(
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=30",
        "-o", "ConnectionAttempts=1",
        "-o", "BatchMode=no"
    )
} else {
    @(
        "-i", $SshKey,
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=30",
        "-o", "ConnectionAttempts=1"
    )
}
if ($LegacySshRsaHostKey) {
    $sshBase = $sshBase + @(
        "-o", "HostkeyAlgorithms=+ssh-rsa",
        "-o", "PubkeyAcceptedAlgorithms=+ssh-rsa"
    )
}

if ([string]::IsNullOrWhiteSpace($RecoveryTargets)) {
    $recoveryHostList = @($Target)
} else {
    $recoveryHostList = @(
        $RecoveryTargets.Split(",") |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne "" }
    )
}
$downHost = if ([string]::IsNullOrWhiteSpace($DownDetectTarget)) { $Target } else { $DownDetectTarget.Trim() }

$swTotal = [Diagnostics.Stopwatch]::StartNew()

if ($PlinkNoPassword) {
    $plinkPwFile = [System.IO.Path]::GetTempFileName()
    Remove-Item -LiteralPath $plinkPwFile -Force -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($plinkPwFile, "`n", [System.Text.UTF8Encoding]::new($false))
}

function Remove-PlinkPwFileSafe {
    param([string] $Path)
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Uploading -> ${SshUser}@${Target}:${RemotePath}"
$swScp = [Diagnostics.Stopwatch]::StartNew()
if ($PlinkNoPassword) {
    if ([string]::IsNullOrWhiteSpace($PlinkHostKey)) {
        Remove-PlinkPwFileSafe $plinkPwFile
        Write-Error "PlinkNoPassword in batch mode requires -PlinkHostKey (e.g. SHA256:... from pscp/plink error text when host key is not cached)."
        exit 6
    }
    $pscpArgs = @("-scp", "-batch", "-hostkey", $PlinkHostKey.Trim(), "-pwfile", $plinkPwFile,
        $imageFull,
        "${SshUser}@${Target}:${RemotePath}"
    )
    & $pscpExe @pscpArgs
    if ($LASTEXITCODE -ne 0) {
        Remove-PlinkPwFileSafe $plinkPwFile
        Write-Error "pscp failed (exit $LASTEXITCODE). If host key not cached, run once interactively: plink ${SshUser}@${Target}"
        exit 1
    }
} else {
    $scpArgs = @()
    if ($ScpLegacyProtocol) { $scpArgs += "-O" }
    $scpArgs = $sshBase + $scpArgs + @(
        "-C",
        $imageFull,
        "${SshUser}@${Target}:${RemotePath}"
    )
    & scp.exe @scpArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "SCP failed (exit $LASTEXITCODE)."
        exit 1
    }
}
$durScp = $swScp.Elapsed
Write-Host ("Upload finished in {0:F1}s." -f $durScp.TotalSeconds)

$remoteArgs = @("-v")
if ($TestOnly) { $remoteArgs += "-T" }
if ($NoKeepConfig) { $remoteArgs += "-n" }
if ($ForceImage) { $remoteArgs += "-F" }
$remoteArgs += $RemotePath
$remoteCmd = "sysupgrade " + ($remoteArgs -join " ")

Write-Host "Running on device: $remoteCmd"
$swSsh = [Diagnostics.Stopwatch]::StartNew()
$sshOut = $null
try {
    if ($PlinkNoPassword) {
        $plinkArgs = @("-ssh", "-batch", "-hostkey", $PlinkHostKey.Trim(), "-pwfile", $plinkPwFile, "${SshUser}@${Target}", $remoteCmd)
        $sshOut = & $plinkExe @plinkArgs 2>&1
    } else {
        $sshArgs = $sshBase + @(
            "${SshUser}@${Target}",
            $remoteCmd
        )
        $sshOut = & ssh.exe @sshArgs 2>&1
    }
} catch {
    Write-Host "(SSH session ended: $($_.Exception.Message))"
}
if ($null -ne $sshOut) {
    $sshOut | ForEach-Object { Write-Host $_ }
}
$sshExit = $LASTEXITCODE
$durSsh = $swSsh.Elapsed
Write-Host ("SSH/sysupgrade session: {0:F1}s (exit {1}; drop after flash is normal)" -f $durSsh.TotalSeconds, $sshExit)

Remove-PlinkPwFileSafe $plinkPwFile
$plinkPwFile = $null

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

Write-Host "Initial grace: waiting ${InitialGraceSeconds}s (after sysupgrade disconnect; grace does NOT mean flash/write finished)..."
Start-Sleep -Seconds $InitialGraceSeconds
$tGraceEnd = $swTotal.Elapsed
$probeStartSec = $tGraceEnd.TotalSeconds + 0.5

$downProbes = 0
$firstDownAt = $null
$firstUpAfterDownAt = $null

$maxLabel = if ($MaxWaitSeconds -gt 0) { "${MaxWaitSeconds}s from SCP start" } else { "unlimited (SCP start)" }
Write-Host "Probing recovery (max $maxLabel, interval ${IntervalSeconds}s): wait '$downHost' ICMP down, then any of [$($recoveryHostList -join ', ')] ICMP up."
while ($true) {
    $elapsed = $swTotal.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("TIMEOUT after {0:F1}s from SCP start." -f $elapsed.TotalSeconds)
        if ($null -eq $firstDownAt) {
            Write-Host "Hint: '$downHost' never went down after grace. Try larger -InitialGraceSeconds or check sysupgrade / cable."
        } else {
            Write-Host "Hint: no ICMP from recovery hosts [$($recoveryHostList -join ', ')] after down."
        }
        exit 1
    }

    $okDown = Test-IcmpReachable -HostOrIp $downHost -TimeoutMs $PingTimeoutMs
    if (-not $okDown) {
        if ($elapsed.TotalSeconds -ge $probeStartSec) {
            $downProbes++
            if ($downProbes -ge $MinDownProbes -and $null -eq $firstDownAt) {
                $firstDownAt = $elapsed
                Write-Host ("[{0,6:F1}s from SCP] '$downHost' appears down (ICMP failed x{1})." -f $elapsed.TotalSeconds, $downProbes)
            }
        }
    } else {
        $downProbes = 0
    }

    if ($null -ne $firstDownAt) { break }

    $sleepMs = [int]([Math]::Max(50, [Math]::Round($IntervalSeconds * 1000.0)))
    Start-Sleep -Milliseconds $sleepMs
}

Write-Host "Waiting for ICMP on recovery host(s)..."
while ($true) {
    $elapsed = $swTotal.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("TIMEOUT after {0:F1}s from SCP start (recovery ICMP)." -f $elapsed.TotalSeconds)
        exit 1
    }
    if (Test-IcmpAnyReachable -Hosts $recoveryHostList -TimeoutMs $PingTimeoutMs) {
        $firstUpAfterDownAt = $elapsed
        Write-Host ("[{0,6:F1}s from SCP] Recovery ICMP OK (one of: $($recoveryHostList -join ', '))." -f $elapsed.TotalSeconds)
        break
    }
    $sleepMs = [int]([Math]::Max(50, [Math]::Round($IntervalSeconds * 1000.0)))
    Start-Sleep -Milliseconds $sleepMs
}

$icmpTotalSec = $swTotal.Elapsed.TotalSeconds
$postGraceToUp = ($firstUpAfterDownAt - $tGraceEnd).TotalSeconds

$durTcpAfterIcmpSec = $null
$totalScpToTcpSec = $null
if ($ProbeTcpPortAfterPing -gt 0) {
    $maxTcpLabel = if ($MaxWaitTcpSeconds -gt 0) { "${MaxWaitTcpSeconds}s after ICMP OK" } else { "unlimited after ICMP OK" }
    Write-Host "Probing TCP port ${ProbeTcpPortAfterPing} (HTTP often after ICMP; max wait $maxTcpLabel, connect timeout ${TcpConnectTimeoutMs}ms)..."
    $swTcp = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($MaxWaitTcpSeconds -gt 0 -and $swTcp.Elapsed.TotalSeconds -ge $MaxWaitTcpSeconds) {
            Write-Error "TIMEOUT: TCP port ${ProbeTcpPortAfterPing} did not accept connections within ${MaxWaitTcpSeconds}s after ICMP recovery."
            exit 1
        }
        if (Test-TcpAnyOpen -Hosts $recoveryHostList -Port $ProbeTcpPortAfterPing -ConnectTimeoutMs $TcpConnectTimeoutMs) {
            $durTcpAfterIcmpSec = $swTcp.Elapsed.TotalSeconds
            $totalScpToTcpSec = $swTotal.Elapsed.TotalSeconds
            Write-Host ("TCP port {0} open {1:F1}s after ICMP recovery ({2:F1}s from SCP start)." -f $ProbeTcpPortAfterPing, $durTcpAfterIcmpSec, $totalScpToTcpSec)
            break
        }
        Write-Host ("[{0,6:F1}s after ICMP] TCP {1} not ready..." -f $swTcp.Elapsed.TotalSeconds, $ProbeTcpPortAfterPing)
        $sleepMs = [int]([Math]::Max(50, [Math]::Round($IntervalSeconds * 1000.0)))
        Start-Sleep -Milliseconds $sleepMs
    }
}

Write-Host ""
Write-Host "========== SYSUPGRADE RECOVERY REPORT =========="
Write-Host ("SSH/SCP target:         {0}" -f $Target)
Write-Host ("Down-detect ICMP:      {0}" -f $downHost)
Write-Host ("Recovery ICMP/TCP:     {0}" -f ($recoveryHostList -join ", "))
Write-Host ("Image:                  {0}" -f $imageFull)
if ($PlinkNoPassword) {
    Write-Host ("Auth:                   Plink -pwfile ({0}, {1})" -f $pscpExe, $plinkExe)
} elseif ($NoSshIdentity) {
    Write-Host "Auth:                   NoSshIdentity (no -i, BatchMode=no)"
} else {
    Write-Host ("SSH key:                {0}" -f $SshKey)
}
if ($LegacySshRsaHostKey) { Write-Host "SSH host key:           +ssh-rsa (LegacySshRsaHostKey)" }
if ($ScpLegacyProtocol) { Write-Host "SCP:                    legacy -O" }
Write-Host ("SCP upload:             {0:F1} s" -f $durScp.TotalSeconds)
Write-Host ("SSH sysupgrade:         {0:F1} s" -f $durSsh.TotalSeconds)
Write-Host ("Initial grace:          {0} s   (after command/disconnect; not flash-complete)" -f $InitialGraceSeconds)
Write-Host ("Total (SCP->ping OK):   {0:F1} s   (after grace, first ping OK following observed down)" -f $icmpTotalSec)
Write-Host ("After grace->ping OK:   {0:F1} s   (grace end -> first ping OK after down)" -f $postGraceToUp)
if ($null -ne $firstDownAt -and $null -ne $firstUpAfterDownAt) {
    $pure = ($firstUpAfterDownAt - $firstDownAt).TotalSeconds
    Write-Host ("Down -> up:             {0:F1} s   (sustained ICMP fail after grace -> first ICMP OK)" -f $pure)
    Write-Host ("First ICMP down at:     {0:F1} s from SCP start" -f $firstDownAt.TotalSeconds)
}
if ($null -ne $durTcpAfterIcmpSec -and $null -ne $totalScpToTcpSec) {
    Write-Host ("ICMP -> TCP {0}:       {1:F1} s   (after first post-recovery ICMP OK)" -f $ProbeTcpPortAfterPing, $durTcpAfterIcmpSec)
    Write-Host ("Total (SCP->TCP {0}):   {1:F1} s" -f $ProbeTcpPortAfterPing, $totalScpToTcpSec)
}
Write-Host ("Note:                   ICMP recovery is not proof sysupgrade NAND completed; use LED / serial if unsure.")
Write-Host "================================================"

exit 0
