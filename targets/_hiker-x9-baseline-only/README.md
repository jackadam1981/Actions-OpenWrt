# `_hiker-x9-baseline-only`（workflow：`baseline_only`）

与 **`hiker_x9-minimal`** 共用同一套 DTS / 精简包（见 `hiker.mk` 里 `Device/hiker_x9-minimal-baseline`），但**不安装** `hiker-x9-minimal-defaults`，用于对比「无首启 uci-defaults」时的行为。

## 联机与 ping 注意（常见误判「900 秒仍未启动」）

1. **LAN 地址**：未跑 `99-hiker-x9-minimal`，因此 **不是** `192.168.100.1`，而是 **OpenWrt 默认 `192.168.1.1`**。若仍对 `192.168.100.1` 做 `ping-until-up`，会一直不通。
2. **无 DHCP**：profile 里去掉了 `dnsmasq`，LAN **不会给电脑自动分配 IP**。请把电脑网卡设为 **静态**，例如 **`192.168.1.10`，子网掩码 `255.255.255.0`**，网关可不填或填 `192.168.1.1`，再 `ping 192.168.1.1` 或浏览器打开 `http://192.168.1.1`。

与 **`hiker_x9-minimal`** 对比：minimal 通过 defaults 把 LAN 设为 **`192.168.100.1`**，你现有脚本若针对 minimal 调的是 `192.168.100.1`，切到 baseline 镜像后必须按上两条改测法。
