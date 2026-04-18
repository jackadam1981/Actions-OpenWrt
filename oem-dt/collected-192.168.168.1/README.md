# 现场采集：`192.168.168.1`（OEM）

- **采集时间（PC 侧）**：2026-04-18（以 git 提交为准）。
- **来源**：`ssh` 至 `root@192.168.168.1`，固定目录 `/tmp/oem-snap-collect`，打包为 `oem-snap-collect.tgz`。
- **发行版摘要**：`openwrt_release` 为 **Chaos Calmer 15.05**（`ramips/rt305x`）；内核见同目录 `uname.txt`（**3.18.140 #11**）。
- **已装包数量**：`opkg_count.txt` → **182**（见 `opkg_list_installed.txt`）。
- **`/etc/os-release`**：该固件上为存根（内容为一行路径）；完整字段见 **`usr_lib_os_release.txt`**（自 `/usr/lib/os-release` 补采）。

原始 tarball：`../oem-snap-collect.tgz`（与 `oem-snap-collect/` 内容对应）。
