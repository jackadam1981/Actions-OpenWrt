# 现场采集：`192.168.168.1`（OEM）

- **采集时间（PC 侧）**：2026-04-18（以 git 提交为准）。
- **来源**：`ssh` 至 `root@192.168.168.1`，固定目录 `/tmp/oem-snap-collect`，打包为 `oem-snap-collect.tgz`。
- **发行版摘要**：`system_release.txt` / `usr_lib_os_release.txt` 已写明 **Chaos Calmer 15.05**、`ramips/rt305x`。**`opkg_distfeeds.conf`** 中各 `src/gz` 均指向 `https://archive.openwrt.org/chaos_calmer/15.05/ramips/rt305x/packages/...`，与上述字段 **一致**，属于对 **15.05 / rt305x 包索引** 的交叉印证（**不是**仅靠猜测；**内核与 rootfs 仍可能含 OEM 补丁/私有包**，与「上游 15.05 树 100% 一致」不是同一命题）。
- **已装包数量**：`opkg_count.txt` → **182**（见 `opkg_list_installed.txt`）。
- **与本仓固件对照**：若要在 **OpenWrt 稳定版（CI 默认 `openwrt-25.12`）** 上追求「全功能路由 + LuCI + WiFi」取向，见 **`hiker_x9-standard`**（`targets/hiker-x9/target/linux/ramips/image/hiker.mk`），其设计说明见 [`targets/README.md`](../../targets/README.md)（**非**本快照包名的逐条移植）。**当前 `standard` 为排查首启未编入 `hiker-x9-standard-defaults`，LAN 多为上游默认（如 `192.168.1.1`）**。**`hiker_x9-minimal`** 亦为上游默认 LAN（**无 LuCI**）；**`192.168.100.1`** 需 **`hiker-x9-standard-defaults`** / **`hiker-x9-minimal-defaults`** 等包或自行 `uci`。OEM 采集机仍可能是 **`192.168.168.1`**。
- **内核（本次扩展）**：`proc_version.txt`（**gcc 4.8.3**、**oem@oem-D3543-A1** 等编译环境串）、`proc_cmdline.txt`、`proc_cpuinfo.txt`、`dmesg_head.txt`；**`/lib/modules/` 下 `.ko` 共 162 个**（`kernel_modules_ko_count.txt`）；**`kernel`/`kmod-*` opkg 条目 84 行**（`opkg_kernel_kmod.txt`）。**无 `/proc/config.gz`**，无法在运行中导出完整 `.config`（见 `kernel_config.txt` 说明）。
- **`/etc/os-release`**：该固件上为存根（内容为一行路径）；完整字段见 **`usr_lib_os_release.txt`**（自 `/usr/lib/os-release` 补采）。

原始 tarball：`../oem-snap-collect.tgz`（与 `oem-snap-collect/` 内容对应）。

## 重启恢复实测（`measure-reboot-recovery.ps1`）

在 **LAN `192.168.168.1`**、**`-LegacySshRsaHostKey`**、**默认探测 TCP 80**、**`InitialGraceSeconds=30`** 条件下（详见 [`targets/README.md`](../../targets/README.md)「重启恢复实测」表）：

| 指标 | 秒（s） |
|------|--------|
| SSH→首次 ICMP（宽限后） | **122.8** |
| 宽限结束→ICMP | **91.2** |
| 掉线→通 | **88.5** |
| 首次掉线（相对 SSH） | **34.3** |
| ICMP→TCP80 | **0.1** |
| SSH→TCP80 | **122.8** |

记录日期：**2026-04-18**（与 `targets/README.md` 表中该行一致）。
