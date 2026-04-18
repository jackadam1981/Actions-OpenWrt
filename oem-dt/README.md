# OEM 设备树与探测导出（`oem-dt`）

本目录存放从 **原厂 / 当前运行系统** 上导出的设备树、MTD、`/lib/upgrade` 片段等。**发行版号与已装软件包列表**不会自动常驻于此；换固件或升级后若要更新记录，需要在仍运行 OEM（或你想存档的那一版）时 **再收集一次**。

## 再收集：版本 + opkg + **内核**

**当前 OEM / 现场 LAN 为 `192.168.168.1` 时**，在 PC 上（仓库根或本目录）执行：

```sh
ssh root@192.168.168.1 'sh -s' < oem-dt/collect-oem-snapshot.sh
```

（本仓 X9 **baseline** 等镜像 LAN 多为 `192.168.1.1`；以你设备实际管理地址为准，把下面命令里的 IP 换掉即可。）

### Windows / 新版 OpenSSH 注意

- 若提示 **no matching host key type … ssh-rsa**：Dropbear 老设备只提供 RSA 主机密钥，需加：
  `-o HostkeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa`
- **`scp` 报 `sftp-server: not found`**：路由上无 SFTP 子系统时，请使用 **`scp -O`**（走传统 scp 协议）。
- **PowerShell 用管道喂 `sh -s`**：若脚本是 CRLF，可能报 `set: illegal option`，请先把脚本转为 **LF** 再传，例如在仓库根目录：

```powershell
$body = [IO.File]::ReadAllText("$PWD\oem-dt\collect-oem-snapshot.sh").Replace("`r`n", "`n").Replace("`r", "`n")
$body | ssh -o HostkeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.168.1 "OEM_SNAPSHOT_DIR=/tmp/oem-snap-collect sh -s"
```

脚本在路由器上生成目录：`/tmp/oem-snapshot-YYYYMMDD-HHMMSS/`，内含：

| 文件 | 说明 |
|------|------|
| `system_release.txt` | `/etc/openwrt_release`、`/etc/os-release`；若存在则追加 **`/usr/lib/os-release`** |
| `usr_lib_os_release.txt` | 存在 `/usr/lib/os-release` 时复制一份（老固件上 `/etc/os-release` 常为存根） |
| `uname.txt` | `uname -a` |
| `dropbear_version.txt` | Dropbear 版本（若有） |
| `proc_mtd.txt` | `/proc/mtd` |
| `board_name.txt` / `model.txt` | 来自 `/tmp/sysinfo/`（若存在） |
| `dt_model.txt` | `/proc/device-tree/model`（若可读） |
| `opkg_list_installed.txt` | `opkg list-installed` 排序后完整列表 |
| `opkg_count.txt` | 上述列表行数（即包数量） |
| `opkg_kernel_kmod.txt` | 从已装列表筛 **`kernel` / `kmod-*`**（内核镜像包与内核模块包） |
| `opkg_kernel_kmod_count.txt` | 上述行数 |
| `proc_version.txt` | `/proc/version`（编译器、#define 版本串等） |
| `proc_cmdline.txt` | `/proc/cmdline` |
| `proc_cpuinfo.txt` | `/proc/cpuinfo` |
| `kernel_modules_dir_ls.txt` | `ls -la /lib/modules/$(uname -r)` |
| `kernel_modules_ko_list.txt` | 该目录下 **`.ko` 全路径**（`find`，已排序） |
| `kernel_modules_ko_count.txt` | `.ko` 个数 |
| `kernel_config.txt` | **`zcat /proc/config.gz`**；若无则一行说明（未开 `CONFIG_IKCONFIG` 时常见） |
| `kernel_config_linecount.txt` | `kernel_config.txt` 行数（有 `config.gz` 时便于扫一眼规模） |
| `dmesg_head.txt` | **`dmesg` 前 160 行**（启动早期日志） |

说明：**已装 `kmod-*` 只表示 rootfs 里带了模块文件**；**正在加载的模块** 还要看 `lsmod` / `modules.autoload` 等，本脚本未默认抓取（避免体量与固件差异过大）；需要时可自行在设备上执行 `lsmod > lsmod.txt` 一并拷入快照目录。

在路由器上打包并拷回：

```sh
ssh root@192.168.168.1 'cd /tmp && tar czf oem-snapshot.tgz oem-snapshot-* && ls -la oem-snapshot.tgz'
scp -O root@192.168.168.1:/tmp/oem-snapshot.tgz .
```

（`scp` 建议同样带上文的 **`HostkeyAlgorithms` / `PubkeyAcceptedAlgorithms`**，与 `ssh` 一致。）

解压后，可将其中文件 **合并或替换** 进 `oem-dt/`（与现有 `proc_mtd.txt`、`model.txt` 等对齐命名即可），并把 **`opkg_*`、`kernel_*`、`proc_*`、`dmesg_head.txt`** 一并纳入版本库，便于以后对比。若 **`kernel_config.txt` 很大**，仍建议保留在快照里（或单独 gzip 存档），便于与自编译 `config` 做 `diff`。

可选：指定输出目录（设备上可写路径）：

```sh
ssh root@192.168.168.1 "OEM_SNAPSHOT_DIR=/root/oem-snap sh -s" < oem-dt/collect-oem-snapshot.sh
```

## 设备树等（历史说明）

- `live.dts`、`dt_export/`、`dt_export.tgz`：来自当时现场的 DT 导出。
- `oem_probe.txt`：当时手工探测摘要（内核、Dropbear、MTD、`/lib/upgrade` 列表等）。
- `oem-upgrade/`：从设备拷贝的 `sysupgrade` / `platform.sh` 等片段，供对照升级逻辑。

若你更新了快照，建议在同一次提交里简短注明采集日期与固件来源（例如「OEM 出厂 Web 版本号」），便于与 `opkg` 列表对应。
