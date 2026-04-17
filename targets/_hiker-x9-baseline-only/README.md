# `_hiker-x9-baseline-only`（workflow：`baseline_only`）

与 **`hiker_x9-minimal`** 共用同一套 DTS / 精简包（见 `hiker.mk` 里 `Device/hiker_x9-minimal-baseline`），但**不安装** `hiker-x9-minimal-defaults`，用于对比「无首启 uci-defaults」时的行为。

## 联机与 ping 注意（常见误判「900 秒仍未启动」）

1. **LAN 地址**：未跑 `99-hiker-x9-minimal`，因此 **不是** `192.168.100.1`，而是 **OpenWrt 默认 `192.168.1.1`**。若仍对 `192.168.100.1` 做 `ping-until-up`，会一直不通。
2. **无 DHCP**：profile 里去掉了 `dnsmasq`，LAN **不会给电脑自动分配 IP**。请把电脑网卡设为 **静态**，例如 **`192.168.1.10`，子网掩码 `255.255.255.0`**，网关可不填或填 `192.168.1.1`，再 `ping 192.168.1.1` 或浏览器打开 `http://192.168.1.1`。

与 **`hiker_x9-minimal`** 对比：minimal 通过 defaults 把 LAN 设为 **`192.168.100.1`**，你现有脚本若针对 minimal 调的是 `192.168.100.1`，切到 baseline 镜像后必须按上两条改测法。

## Breed 里刷 `*-squashfs-sysupgrade.bin`（无串口）

本仓文档里对 **官版 / 原厂 Web 首刷** 推荐的是 **`hiker_x9-factory` 产出的 `factory.bin`**；其它 profile 的 **`sysupgrade.bin`** 主要给 **已在 OpenWrt 上运行** 时用 `sysupgrade`/LuCI 升级。

你在 **Breed** 里直接刷 **`hiker_x9-minimal-baseline` 的 `sysupgrade.bin`**：不少机型上 Breed 能写进去，但若 **刷完一直无任何响应**，仍可能是 **镜像与 Breed 写入格式/校验** 或 **分区偏移** 与「从运行中的 OpenWrt 做 sysupgrade」路径不一致；无串口时难以区分「内核没起来」和「起来了但 IP 测错」。

**建议顺序（仍无串口）**：

1. **先按上文改测法**：PC 设 **`192.168.1.10/24`**，只测 **`ping 192.168.1.1`**（不要 `192.168.100.1`），上电后等 **2～5 分钟** 再判死（首次写 flash + 扫块可能偏慢）。
2. 若仍完全不通：用 Breed **改刷一次** 全量构建里的 **`hiker_x9-factory` → `factory.bin`**（或你已知能启动的 **`hiker_x9-minimal` 的 `sysupgrade.bin`**），确认硬件与 Breed 写入链路正常后，再在已运行的 OpenWrt 里做 **`minimal-baseline` 的 sysupgrade** 对比 baseline。
