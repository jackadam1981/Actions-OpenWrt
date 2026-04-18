# targets 目录说明

每个子目录代表一个编译目标（硬件/型号），矩阵编译会遍历所有包含 `.config` 的目标。

## 结构

- **targets/****/.config** — 必选，该目标的 OpenWrt 编译配置。
- **targets/****/target/** — 可选，覆盖到 OpenWrt 源码的 `target/`（如上游不支持的型号可放 `target/linux/*` 等）。
- **targets/****/package/** — 可选，覆盖到 OpenWrt 源码的 `package/`（适合补充自定义包或专有二进制封装）。
- **targets/****/etc/** — 可选，覆盖到 `package/base-files/files/etc/`（固件内 `/etc` 默认文件）。

## 示例

- 仅用上游支持的设备：`targets/dir-505/.config`、`targets/x86-64/.config`。
- 上游不支持的型号（如 hiker-x9）：`targets/hiker-x9/.config` + `targets/hiker-x9/target/linux/*`**，可选 `targets/hiker-x9/etc/*`**。构建时会先拷贝 `.config`，再 rsync `target/`、`etc/` 到源码树。

## 添加新目标

1. 新建目录 `targets/<目标名>/`。
2. 放入 `targets/<目标名>/.config`。
3. 如需自定义内核/设备树等，在 `targets/<目标名>/target/` 下按 OpenWrt 源码结构放置（如 `target/linux/mediatek/...`）。
4. 如需自定义 package（例如打包专有静态二进制、附带 init 脚本），可放在 `targets/<目标名>/package/` 下。
5. 如需该型号默认的 `/etc` 文件，在 `targets/<目标名>/etc/` 下放置，会合并到 `package/base-files/files/etc/`。

---

## hiker-x9 与 openwrt-custom-devices

当前 hiker-x9 采用 **ramips / rt305x + 设备 overlay** 的方式扩展，不再依赖单独的 `printserver` target。仓库会在构建时把 `targets/hiker-x9/target/linux/ramips/` **合并**进 OpenWrt 源码树，并把额外的 `hiker.mk` 接入 `rt305x.mk`。

**上游 OpenWrt 里 `SOC := rt5350` 的常见写法**（见官方 `[target/linux/ramips/image/rt305x.mk](https://github.com/openwrt/openwrt/blob/master/target/linux/ramips/image/rt305x.mk)`）：多数 **家用路由** 条目只写 `SOC` / `IMAGE_SIZE` / `DEVICE_VENDOR` / `DEVICE_MODEL` / `SUPPORTED_DEVICES`（及个别 `IMAGES`），**不写 `DEVICE_PACKAGES`**，即完全交给 `**target/linux/ramips/rt305x/target.mk**` 里的 `**DEFAULT_PACKAGES += kmod-rt2800-soc wpad-basic-mbedtls swconfig**`，再叠 `**include/target.mk**` 里 **路由器类型** 的默认包（`dnsmasq`、`firewall`、`odhcpd-ipv6only`、`ppp` 等，随版本略有变动）。只有在板子带 **USB / 摄像头 / SPI 等额外硬件** 时，上游才在 `DEVICE_PACKAGES` 里 **追加** `kmod-usb-*`、`kmod-video-*` 等，而不是像本仓 `minimal` 那样大面积 `**-包名` 精简**。例如同文件中的 `**dlink_dir-300-b7`**、`**dlink_dir-320-b1`**、`**belkin_f7c027**`、`**omnima_miniembplug**` 等 rt5350 机型均无 `DEVICE_PACKAGES`；`**7links_px-4885-***`、`**dlink_dcs-930l-b1**` 等则只加与硬件相关的 kmod。开发板 `**8devices_carambola**` 显式写了 `**DEVICE_PACKAGES :=`（空）** 表示「零额外包」。`**hiker_x9-minimal-baseline`**：**包栈对齐上游 ramips/rt305x「小路由」默认**（[`rt305x/target.mk` 的 DEFAULT_PACKAGES](https://github.com/openwrt/openwrt/blob/master/target/linux/ramips/rt305x/target.mk) + 路由器 profile 常见默认如 `dnsmasq` / `firewall` / `ppp` 等，随上游版本略有变动），**不做 `−包名` 式精简**；**仅追加 `urngd`**（首启熵）。与 DIR-505 等「只写板级信息、包交给 target」的上游机型同思路，便于和本仓 **`minimal`** 对照。

- **targets/hiker-x9/.config**：`CONFIG_TARGET_ramips=y`、`CONFIG_TARGET_ramips_rt305x=y`、`**CONFIG_TARGET_MULTI_PROFILE=y`**、`**CONFIG_TARGET_PER_DEVICE_ROOTFS=y`**，以及多个 `**CONFIG_TARGET_DEVICE_ramips_rt305x_DEVICE_<机型>=y**`（注意是 `**TARGET_DEVICE_…**` 前缀，不是 `TARGET_ramips_rt305x_DEVICE_…`；后者属于单 profile 的 choice，与多选互斥）。否则 `make defconfig` 会收成单一 `CONFIG_TARGET_PROFILE`，只编出一个 profile。默认同时编译：
  - **`hiker_x9-minimal-baseline`**（[`targets/_hiker-x9-baseline-only/.config`](_hiker-x9-baseline-only/.config)、workflow **`baseline_only`**）：与 **`minimal`** **同 DTS**；**包 = 上游小路由默认 + `urngd`**；**不装** `hiker-x9-minimal-defaults`。LAN 多为 **`192.168.1.1`**、常有 DHCP；**勿用** `192.168.100.1` 测。详见 [`targets/_hiker-x9-baseline-only/README.md`](_hiker-x9-baseline-only/README.md)。
  - **`hiker_x9-standard`（标准版）**：与 **`minimal`** **同 DTS**；**不**使用 `HIKER_X9_STRIP`（保留上游默认的 `dnsmasq` / `firewall` / `ppp` 等路由器栈）；另装 **`luci`**（完整 LuCI 元包）、**`dnsmasq-full`**、**`wpad-openssl`** + **`iw` / `iwinfo`**、常用 **USB 存储与 USB 网卡 kmod**、`relayd` 等，意图在 **当前 OpenWrt master feed** 上**贴近** [`oem-dt/collected-192.168.168.1/`](oem-dt/collected-192.168.168.1/) 里 OEM **`opkg_list_installed` 的角色**（**不是**把 182 条包名逐条搬进 `DEVICE_PACKAGES`：内核与包版本与 OEM 3.18 树不对齐；`panel-ap-setup`、`luci-theme-Rosy` 等也不在官方 feed）。首启 **`hiker-x9-standard-defaults`**：LAN **`192.168.100.1`**（与 **`minimal`** 一致，便于同一网段切换 profile）、WAN `proto=none`（与 `minimal` 同思路，避免未插上行时 `udhcpc` 拖慢启动）。若 CI **`check-size` 失败**，可在 `hiker.mk` 中先收窄体积（例如去掉 **`relayd`**、改 **`dnsmasq-full` → 默认 `dnsmasq`**、或 **`wpad-openssl` → `wpad-mbedtls`**）。
  - `hiker_x9-minimal`（**黄金底镜像**：有线 LAN + `luci-light` 与基础中文界面；不拉 WiFi AP用户态，并从该 profile 去掉 `wpad` / `iw` / `iwinfo`。**实测参考**：刷写后 LAN 侧用 `ping-until-up` 计时至首次 **ping 通** 约 **680 s**（约 11 min，随环境与存储略有出入）；**LAN 为 `192.168.100.1`**（由 `hiker-x9-minimal-defaults` 写入））
  - `hiker_x9-factory`（**官版首刷**：与 minimal 类似的精简栈，另含 `**hiker-x9-breed-autoflash`**；生成 `**factory.bin`**，**可由官版 / 原厂 Web 或恢复流程直接刷入**；刷机后见下文「红灯不再闪烁」再断电操作）
  - `hiker_x9-p910nd`
  - `hiker_x9-p910nd-wifi`
  - `hiker_x9-p910nd-wifi-lite`
  - `hiker_x9-virtualhere`
  - `hiker_x9-virtualhere-wifi`
  - `hiker_x9-both`（**p910nd + VirtualHere**，有线；与 `minimal` 相同 WiFi 用户态剔除策略）
  - `hiker_x9-both-wifi`（同上 + **AP WiFi 栈**）
- `**package/network/services/`** 下与上述功能 profile 对应的 defaults 目录（各含 `Makefile` + `files/`）：`hiker-x9-minimal-defaults`、`**hiker-x9-standard-defaults**`、`hiker-x9-p910nd-defaults`、`hiker-x9-p910nd-wifi-defaults`、`hiker-x9-virtualhere-defaults`、`hiker-x9-virtualhere-wifi-defaults`、`hiker-x9-both-defaults`、`hiker-x9-both-wifi-defaults`（`**hiker_x9-factory` 复用 `hiker-x9-minimal-defaults`**，无单独 `*-factory-defaults`）；另有共用的 `**virtualhere-usb-server`** 与 `**hiker-x9-reset-button**`（安装 `/etc/rc.button/reset`，各 `*-defaults` 通过 `DEPENDS` 拉入）。
- 若要继续扩展 hiker-x9 新版本，可在 `targets/hiker-x9/target/linux/ramips/image/hiker.mk` 增加新的 `Device/...` profile，并按需补 `dts/`、`package/`、`etc/`。

### 首启很慢、SSH 很久才通（常见原因）

1. **Dropbear 首次生成 host key**（`/etc/dropbear/dropbear_*_host_key`）：在 RT5350 上若熵不足，`dropbearkey` 可能极慢。`hiker_x9-minimal` / `factory` 已加入 `**urngd`** 以加快随机数（仍建议首次上电多等一会儿）。
2. **WAN 默认 `dhcp`、网线未插**：`udhcpc` 会长时间重试，拖慢 `netifd` 与后续服务。`99-hiker-x9-minimal` 在首启把 `**network.wan.proto` 置为 `none`**（纯 LAN 场景）；若你确实要用 WAN 拨号/上联，刷机后在 `/etc/config/network` 里改回 `dhcp`/`pppoe` 等。
3. **自行对照日志**：SSH 能登录后执行 `**logread -e hiker-mini -e dropbear -e netifd`** 看 `uci-defaults` 与网络、SSH 启动的相对时间；`**dmesg | tail`** 看内核阶段是否异常慢。

### hiker-x9：`DEVICE_PACKAGES` 一览（对照 `hiker.mk`）

以下只统计 `**hiker.mk` 里每个 profile 的显式项**：以 `**+`** 表示强制装入，`**−`** 表示从 **该 subtarget 的默认包集合** 中剔除（OpenWrt 的 `-包名` 语义）。  
**未出现在表里的包**：仍可能来自 **ramips/rt305x 路由器镜像的默认包**（如 `dropbear`、`firewall`、`dnsmasq` 等，随上游版本略有变动），除非被 `**−`** 去掉。

#### 表 A — 显式装入（`+`）


| 包名                                                         | minimal | p910nd | p910nd-wifi | virtualhere | virtualhere-wifi | both | both-wifi |
| ---------------------------------------------------------- | ------- | ------ | ----------- | ----------- | ---------------- | ---- | --------- |
| `luci-light`                                               | +       | +      | +           | +           | +                | +    | +         |
| `luci-theme-bootstrap`                                     | +       | +      | +           | +           | +                | +    | +         |
| `luci-i18n-base-zh-cn`                                     | +       | +      | +           | +           | +                | +    | +         |
| `p910nd`                                                   |         | +      | +           |             |                  | +    | +         |
| `luci-app-p910nd`                                          |         | +      | +           |             |                  | +    | +         |
| `luci-i18n-p910nd-zh-cn`                                   |         | +      | +           |             |                  | +    | +         |
| `kmod-usb-core`                                            |         | +      | +           | +           | +                | +    | +         |
| `kmod-usb-ohci`                                            |         | +      | +           | +           | +                | +    | +         |
| `kmod-usb2`                                                |         | +      | +           | +           | +                | +    | +         |
| `kmod-usb-printer`                                         |         | +      | +           |             |                  | +    | +         |
| `kmod-mac80211`                                            |         |        | +           |             | +                |      | +         |
| `kmod-rt2800-lib` / `kmod-rt2800-mmio` / `kmod-rt2800-soc` |         |        | +           |             | +                |      | +         |
| `kmod-rt2x00-lib` / `kmod-rt2x00-mmio`                     |         |        | +           |             | +                |      | +         |
| `wpad-mbedtls`                                             |         |        | +           |             | +                |      | +         |
| `iw`                                                       |         |        | +           |             | +                |      | +         |
| `iwinfo`                                                   |         |        | +           |             | +                |      | +         |
| `virtualhere-usb-server`                                   |         |        |             | +           | +                | +    | +         |
| `hiker-x9-minimal-defaults`                                | +       |        |             |             |                  |      |           |
| `hiker-x9-p910nd-defaults`                                 |         | +      |             |             |                  |      |           |
| `hiker-x9-p910nd-wifi-defaults`                            |         |        | +           |             |                  |      |           |
| `hiker-x9-virtualhere-defaults`                            |         |        |             | +           |                  |      |           |
| `hiker-x9-virtualhere-wifi-defaults`                       |         |        |             |             | +                |      |           |
| `hiker-x9-both-defaults`                                   |         |        |             |             |                  | +    |           |
| `hiker-x9-both-wifi-defaults`                              |         |        |             |             |                  |      | +         |


#### 表 B — 显式剔除（`−`）


| 包名                   | minimal | p910nd | p910nd-wifi | virtualhere | virtualhere-wifi | both | both-wifi |
| -------------------- | ------- | ------ | ----------- | ----------- | ---------------- | ---- | --------- |
| `wpad-basic-mbedtls` | −       |        | −           |             | −                | −    | −         |
| `iw`                 | −       |        |             |             |                  | −    |           |
| `iwinfo`             | −       |        |             |             |                  | −    |           |


#### 读表提示

- `**hiker_x9-factory`**：显式包与 minimal 同表思路，另加 `**hiker-x9-breed-autoflash`**，并定义 `**IMAGES += factory.bin`**；**官版首刷请选该 profile 产物 `factory.bin`**，勿与仅 `sysupgrade` 的 profile 混用在原厂恢复页上。
- `**p910nd-wifi` / `virtualhere-wifi` / `both-wifi**`：`−wpad-basic-mbedtls` 与 `**+wpad-mbedtls**` 搭配，避免两套 wpad 冲突（与历史构建错误同源）。
- **每个功能 profile 对应一个 `hiker-x9-*-defaults` 包**（目录在 `package/network/services/`），首启逻辑与 banner 分 profile 维护；**复位键脚本** 集中在 `**hiker-x9-reset-button`**；`**both*`** 仍不复用 `**virtualhere-*-defaults**`。
- `**minimal**`：保留 LuCI 与中文，`**+hiker-x9-minimal-defaults**`，且 `**−wpad-basic-mbedtls**`、`**−iw` / `−iwinfo**`；内核里是否仍带无线相关模块取决于全局内核配置，不在本表范围。
- `**p910nd`（无 WiFi）**：未写 `**−wpad-*`**，即 **沿用该 target 默认的 wpad 组合**（若与后续精简策略冲突，可再单独加 `−` 行对齐 `minimal`）。

**参考仓库** [jackadam1981/openwrt-custom-devices](https://github.com/jackadam1981/openwrt-custom-devices) 仍可查阅历史设备思路；**CI 已不再通过 feed 引入**。增硬件与机型请只在 `targets/<name>/` 下维护 overlay（`target/`、`package/`、`etc/`），由 `diy-part2.sh` 合并进 OpenWrt 源码树。

---

## 如何修正 base-files.version / base-files= 报错（printserver + APK）

报错含义：`package/Makefile` 在 APK 安装阶段会执行  
`"base-files=$(shell cat $(STAGING_DIR)/base-files.version)"`，若该文件不存在则得到 `base-files=`，APK 会报「不是合法依赖格式」。

**base-files.version 由谁生成**：在 **package/base-files/Makefile** 里，当 `CONFIG_USE_APK=y` 时，在 **Package/base-files/install** 步骤末尾会执行：  
`echo $(PKG_RELEASE)~$(REVISION) >$(STAGING_DIR)/base-files.version`。  
也就是说：只有 **base-files 被编译并执行了 install** 后，该文件才会出现。

**根本原因**：printserver 目标下当前没有把 base-files 纳入要安装的包，或 build 顺序/多 profile 导致 base-files 未在该 staging 目录下安装，所以 `base-files.version` 未被生成。

**推荐修正方式（任选其一或并用）**：

1. **OpenWrt 主线**
  在 printserver 目标或对应设备的定义里，把 **base-files** 加入该 target 的默认包（例如 `DEFAULT_PACKAGES` 或 profile 的包列表），保证会执行 `package/base-files` 的 compile + install，从而在 `$(STAGING_DIR)/base-files.version` 生成文件。
2. **openwrt-custom-devices**
  仓库中已为 printserver hiker-x9 增加默认包 profile，参考 RT5350/ramips 的默认集（与 `include/target.mk` 一致的基础包 + router 类型包 + kmod-leds-gpio、kmod-gpio-button-hotplug）：  
   **target/linux/printserver/profiles/hiker-x9.mk** 中定义了 `Profile/hikerx9` 的 `PACKAGES`（含 base-files、libc、netifd、dnsmasq、firewall4 等）。  
   在 OpenWrt 中需让 printserver 目标 **include 该 profiles 目录**（例如在 printserver 的 Makefile 里通过 `IncludeProfiles` 或 `-include profiles/hiker-x9.mk`），这样选 CONFIG_TARGET_printserver_hikerx9 时才会带上这些默认包，从而生成 base-files.version。
3. **本仓兜底（diy-part2.sh）**
  若暂时无法改上游，可在本仓的 diy-part2 里对使用 APK 的 printserver 构建**强制选中 base-files**（见下），让 base-files 参与编译和 install，从而生成 `base-files.version`。

---

## 刷机与 bin 产物分析

> **刷机后请先看灯再操作**：写入完成并首次启动期间，**电源旁红灯往往会闪烁**（表示仍在写入或系统尚未就绪）。**请等到红灯不再闪烁**（一般为常亮或熄灭，以机型为准）**后再认为设备已正常启动**；在此之前请勿反复断电、拔电或强行中断，以免变砖或分区损坏。**从官版首刷**请使用 **hiker_x9-factory** 的 **factory.bin**（见上文与 [刷机文档](../docs/flashing-from-bin-and-source.md)）。

构建产物位于 OpenWrt 源码树内的 `bin/targets/...`（CI 中随 Artifact 下载）。根据本仓各 target 推断镜像类型、分区与 Wiki 对照的步骤见 [docs/flashing-from-bin-and-source.md](../docs/flashing-from-bin-and-source.md)。

**刷机后测「多久能 ping 通」**：Windows 用 [`scripts/ping-until-up.ps1`](../scripts/ping-until-up.ps1)，Linux / macOS 用 [`scripts/ping-until-up.sh`](../scripts/ping-until-up.sh)（刷机后 PC 接 LAN，默认探测 `192.168.1.1`）。**`.ps1` 可加 `-ProbeTcpPort 80`**，首 ICMP 通后**同一时钟**继续等到 **TCP 80**（**U-Boot 刷 X9 baseline** 等无 SSH 场景见 [`targets/_hiker-x9-baseline-only/README.md`](_hiker-x9-baseline-only/README.md)）。**`.ps1` 运行时提示为英文**；探测用 **.NET ICMP**，不用 `Test-Connection -TimeoutSeconds`（PS 5.1 会恒失败）。**已在系统内** SCP + `sysupgrade` 全程计时用 [`measure-sysupgrade-recovery.ps1`](../scripts/measure-sysupgrade-recovery.ps1)（可加 `-ProbeTcpPortAfterPing 80`、PuTTY 需 `-PlinkHostKey`）。**能 SSH 时测「重启到恢复」**优先用 [`measure-reboot-recovery.ps1`](../scripts/measure-reboot-recovery.ps1)：会下发 `reboot`、宽限后再判 **ICMP 先掉线再恢复**；**默认在 ICMP 恢复后继续探测 TCP 80**（`-ProbeTcpPortAfterPing 0` 可改为仅 ping）。OEM / 老 Dropbear 仅 RSA 主机密钥时加 **`-LegacySshRsaHostKey`**，例如 `-Target 192.168.168.1`。

**实测记录（供预期）**：下列时间为 **秒（s）**；**SCP→ICMP**、**SCP→TCP80** 指自本机 **SCP 开始** 到脚本判定恢复；**掉线→通** / **宽限→ICMP** 见 [`measure-sysupgrade-recovery.ps1`](../scripts/measure-sysupgrade-recovery.ps1)（宽限默认 30s，宽限后须 **先 ICMP 掉线再通**）。**「—」** 表示当次未测。**`-PlinkHostKey`** 在 `-n` 刷机后常会变；跨分支可能加 **`-ForceImage`**。同机多次刷写负载不同，**仅作粗预期**。

| 设备 | 场景 / 镜像 | 条件摘要 | SCP→ICMP | 掉线→通 | 宽限→ICMP | 首次掉线 (SCP 后) | ICMP→TCP80 | SCP→TCP80 | 备注 |
|------|-------------|----------|----------|---------|-----------|------------------|------------|-----------|------|
| D-Link DIR-505 | U-Boot / 恢复页 **19.07.8 factory** | 非脚本；PC 计首 ICMP | **86.6** | — | — | — | — | — | 约 90s 内粗预期 |
| D-Link DIR-505 | **25.12.0 ath79** sysupgrade | 自 ar71xx 升、`sysupgrade -F`、TCP80 | **110.1** | 18.0 | 68.5 | 92.1 | **76.7** | **186.7** | ping 后 Web 仍晚约 77s |
| D-Link DIR-505 | **19.07.8** ar71xx 刷回 | 自 25.12 ath79、`sysupgrade -F`、TCP80 | **76.9** | 12.0 | 40.1 | 64.9 | **44.1** | **121.0** | ping 后 Web 晚约 44s |

### 重启恢复实测（[`measure-reboot-recovery.ps1`](../scripts/measure-reboot-recovery.ps1)）

与上表 **sysupgrade / SCP** 口径不同：本表为 **`ssh … reboot` 后** 本机探测；**SSH→ICMP** = 自 SSH 下发 `reboot` 起至**宽限后**首次 ping 通；**宽限→ICMP** = 宽限结束至该次 ping 通；**掉线→通** = 宽限后首次持续 ICMP 失败至再次 ping 通；**首次掉线** = 自 SSH 起至判定掉线。**默认测 TCP 80**（`-ProbeTcpPortAfterPing 0` 可仅 ICMP）。

| 设备 | 场景 / 条件 | SSH→ICMP | 宽限→ICMP | 掉线→通 | 首次掉线 (SSH 后) | ICMP→TCP80 | SSH→TCP80 | 备注 |
|------|-------------|----------|----------|---------|------------------|------------|-----------|------|
| Hiker X9 OEM | LAN **192.168.168.1**，`-LegacySshRsaHostKey`，默认 TCP80、宽限 30s | **122.8** | **91.2** | **88.5** | **34.3** | **0.1** | **122.8** | 2026-04-18 单次；ICMP 与 Web 几乎同时 |

