# `_hiker-x9-baseline-only`（workflow：`baseline_only`）

与 **`hiker_x9-minimal`** 共用 **同一 DTS**（`rt5350_hiker_x9-minimal`）。**`hiker_x9-minimal-baseline`** 的 **`DEVICE_PACKAGES` 只有 `urngd`**：即 **ramips/rt305x 上游「小路由」默认包栈**（`dnsmasq`、`firewall`、`ppp`、`wpad` 等，随 OpenWrt 版本略有变动），**与 DIR-505 类上游镜像同档思路**，不做本仓 `minimal` 那种大面积 `−包名` 精简。策略说明见 **`targets/README.md`** 及官方 [`rt305x.mk`](https://github.com/openwrt/openwrt/blob/openwrt-25.12/target/linux/ramips/image/rt305x.mk)、[`rt305x/target.mk`](https://github.com/openwrt/openwrt/blob/openwrt-25.12/target/linux/ramips/rt305x/target.mk)（与 CI 默认分支一致）。

用途：对比 **「无本仓 uci-defaults、无自定义 strip」** 下的启动行为；一般比 `minimal` **更快拿到 DHCP / ping 通**（若仍极慢，再查刷机方式或硬件）。

## 联机与 ping（与 `minimal` 对比）

| 项目 | `hiker_x9-minimal` | `hiker_x9-minimal-baseline`（上游小路由默认 + `urngd`） |
|------|--------------------|--------------------------------------|
| LAN 地址 | **`192.168.100.1`**（defaults 写入） | 多为 **`192.168.1.1`**（上游默认） |
| DHCP | 无（profile 曾 strip `dnsmasq`） | **通常有**（保留上游默认 dnsmasq 等） |
| `ping-until-up` | 常用 `-Target 192.168.100.1` | 默认 **`192.168.1.1`** 即可；或接 LAN 等 DHCP 后再 ping 网关 |

若仍对 **`192.168.100.1`** 测 baseline，会一直不通，**不是**没启动。

## U-Boot / Web 刷 **baseline** 后怎么测「多久起来」（无 SSH）

`measure-sysupgrade-recovery.ps1` 依赖 **SCP + SSH**，**U-Boot 直刷**后通常还 **没有密钥/空密码策略也不便自动化**，因此用 **`ping-until-up`** 在本机计时即可（与 DIR-505 刷 factory 后同一类流程）。

1. **PC 网线接 X9 LAN**，本机网卡设静态或接上游 DHCP（按你现场）。
2. 选定 **T0**：例如 **U-Boot/Web 提示写入完成并复位** 的瞬间，或你 **手动断电再上电** 的时刻（**全程只用一个 T0**，不要混用）。
3. **在 T0 同时**开终端执行（baseline LAN 多为 **`192.168.1.1`**）：

   ```powershell
   .\scripts\ping-until-up.ps1 -Target 192.168.1.1 -ProbeTcpPort 80
   ```

   会先打印 **首 ICMP 通** 的秒数；若加了 **`-ProbeTcpPort 80`**，同一计时下再打印 **TCP 80 可连**（LuCI/uHTTPd 常晚于 ping）。

4. 可选 **`-MaxWaitSeconds 900`** 避免无限等；Linux/macOS 用 **`ping-until-up.sh`**，带 TCP 时需 **`nc`**：`./scripts/ping-until-up.sh 192.168.1.1 1 0 80`。

CI **只能手动 dispatch** 时：先下 Artifact 拿 **`…hiker_x9-minimal-baseline…sysupgrade.bin`**（或你们 U-Boot 实际接受的镜像名），按 Breed/Web 流程刷入，再在 PC 上跑上述脚本即可。

## Breed 里刷 `*-squashfs-sysupgrade.bin`（无串口）

本仓 **已移除** **`hiker_x9-factory` / `factory.bin`**（采集用 OEM 为较老 OpenWrt 衍生，非真正出厂首版，见 [targets/README.md](../README.md)）。**Breed / Web 首刷**请使用现场可接受的镜像（常为某 profile 的 **`sysupgrade.bin`**，以 Breed 说明为准）；若异常，可用 **`minimal`** 等镜像先确认链路，再在系统内对 **`minimal-baseline`** 做 `sysupgrade`。
