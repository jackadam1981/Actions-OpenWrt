# `_hiker-x9-baseline-only`（workflow：`baseline_only`）

与 **`hiker_x9-minimal`** 共用 **同一 DTS**（`rt5350_hiker_x9-minimal`）。**`hiker_x9-minimal-baseline`** 在 **上游默认包栈** 之上 **仅追加 `urngd`**（减轻首启 `dropbearkey` 因熵不足变慢）；策略说明见 **`targets/README.md`**「上游 OpenWrt 里 `SOC := rt5350` 的常见写法」及官方 [`rt305x.mk`](https://github.com/openwrt/openwrt/blob/master/target/linux/ramips/image/rt305x.mk)。

用途：对比 **「无本仓 uci-defaults、无自定义 strip」** 下的启动行为；一般比 `minimal` **更快拿到 DHCP / ping 通**（若仍极慢，再查刷机方式或硬件）。

## 联机与 ping（与 `minimal` 对比）

| 项目 | `hiker_x9-minimal` | `hiker_x9-minimal-baseline`（当前） |
|------|--------------------|--------------------------------------|
| LAN 地址 | **`192.168.100.1`**（defaults 写入） | 多为 **`192.168.1.1`**（上游默认） |
| DHCP | 无（profile 曾 strip `dnsmasq`） | **通常有**（保留上游默认 dnsmasq 等） |
| `ping-until-up` | 常用 `-Target 192.168.100.1` | 默认 **`192.168.1.1`** 即可；或接 LAN 等 DHCP 后再 ping 网关 |

若仍对 **`192.168.100.1`** 测 baseline，会一直不通，**不是**没启动。

## Breed 里刷 `*-squashfs-sysupgrade.bin`（无串口）

本仓对 **官版 / 原厂首刷** 更推荐 **`hiker_x9-factory` → `factory.bin`**；其它 profile 的 **`sysupgrade.bin`** 多在 **已运行 OpenWrt** 下升级用。Breed 直刷 sysupgrade 若异常，可先 factory/minimal 确认链路，再在系统内做 baseline 的 sysupgrade。
