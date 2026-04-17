<#
.SYNOPSIS
  SCP 上传镜像并 SSH 执行 sysupgrade，计时「刷写到再次 ping 通」耗时（与 measure-reboot-recovery 同类）。

.DESCRIPTION
  sysupgrade 会话结束（SSH 常断开）后先等待 InitialGraceSeconds：此窗口**不表示** NAND 刷写已完成，仅避免立刻用 ICMP 误判。
  宽限结束后与 measure-reboot-recovery 相同：须先观测连续 MinDownProbes 次 ICMP 失败（掉线），再等到 ping 通，才记为「可 ping 恢复」。ICMP 恢复仍**不等于**镜像写入完成，实机请以指示灯等为准。
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

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.100.1 -Image D:\build\*-squashfs-sysupgrade.bin

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.100.1 -Image .\firmware.bin -NoKeepConfig -InitialGraceSeconds 45

.EXAMPLE
  .\scripts\measure-sysupgrade-recovery.ps1 -Target 192.168.1.1 -Image .\Firmware\sysupgrade.bin -PlinkNoPassword -PlinkHostKey "SHA256:YOUR_FINGERPRINT"
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
} elseif (-not (Test-Path -LiteralPath $SshKey)) {
    Write-Error "SSH key not found: $SshKey (use -PlinkNoPassword for root with empty password via PuTTY)"
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
} else {
    @(
        "-i", $SshKey,
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=30",
        "-o", "ConnectionAttempts=1"
    )
}

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
    $scpArgs = $sshBase + @(
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
Write-Host "Probing ping recovery (max $maxLabel, interval ${IntervalSeconds}s; require down then up after grace)..."
while ($true) {
    $elapsed = $swTotal.Elapsed
    if ($MaxWaitSeconds -gt 0 -and $elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ("TIMEOUT after {0:F1}s from SCP start." -f $elapsed.TotalSeconds)
        if ($null -eq $firstDownAt) {
            Write-Host "Hint: ICMP never went down after grace. Reboot/flash may have finished during grace, or link stayed up (still old stack). ICMP OK is not proof NAND finished — see LEDs; try larger -InitialGraceSeconds or check sysupgrade."
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
                Write-Host ("[{0,6:F1}s from SCP] Link appears down (ICMP failed x{1})." -f $elapsed.TotalSeconds, $downProbes)
            }
        }
    }

    $sleepMs = [int]([Math]::Max(50, [Math]::Round($IntervalSeconds * 1000.0)))
    Start-Sleep -Milliseconds $sleepMs
}

$durTotal = $swTotal.Elapsed.TotalSeconds
$postGraceToUp = ($firstUpAfterDownAt - $tGraceEnd).TotalSeconds

Write-Host ""
Write-Host "========== SYSUPGRADE RECOVERY REPORT =========="
Write-Host ("Target:                 {0}" -f $Target)
Write-Host ("Image:                  {0}" -f $imageFull)
if ($PlinkNoPassword) {
    Write-Host ("Auth:                   Plink -pwfile ({0}, {1})" -f $pscpExe, $plinkExe)
} else {
    Write-Host ("SSH key:                {0}" -f $SshKey)
}
Write-Host ("SCP upload:             {0:F1} s" -f $durScp.TotalSeconds)
Write-Host ("SSH sysupgrade:         {0:F1} s" -f $durSsh.TotalSeconds)
Write-Host ("Initial grace:          {0} s   (after command/disconnect; not flash-complete)" -f $InitialGraceSeconds)
Write-Host ("Total (SCP->ping OK):   {0:F1} s   (after grace, first ping OK following observed down)" -f $durTotal)
Write-Host ("After grace->ping OK:   {0:F1} s   (grace end -> first ping OK after down)" -f $postGraceToUp)
if ($null -ne $firstDownAt -and $null -ne $firstUpAfterDownAt) {
    $pure = ($firstUpAfterDownAt - $firstDownAt).TotalSeconds
    Write-Host ("Down -> up:             {0:F1} s   (sustained ICMP fail after grace -> first ICMP OK)" -f $pure)
    Write-Host ("First ICMP down at:     {0:F1} s from SCP start" -f $firstDownAt.TotalSeconds)
}
Write-Host ("Note:                   ICMP recovery is not proof sysupgrade NAND completed; use LED / serial if unsure.")
Write-Host "================================================"

exit 0
