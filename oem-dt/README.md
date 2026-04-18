# OEM 设备树与探测导出（`oem-dt`）

本目录存放从 **原厂 / 当前运行系统** 上导出的设备树、MTD、`/lib/upgrade` 片段等。**发行版号与已装软件包列表**不会自动常驻于此；换固件或升级后若要更新记录，需要在仍运行 OEM（或你想存档的那一版）时 **再收集一次**。

## 再收集：版本 + opkg 清单

在 PC 上（仓库根或本目录）对路由器执行（将 `192.168.1.1` 换成实际 LAN 地址）：

```sh
ssh root@192.168.1.1 'sh -s' < oem-dt/collect-oem-snapshot.sh
```

脚本在路由器上生成目录：`/tmp/oem-snapshot-YYYYMMDD-HHMMSS/`，内含：

| 文件 | 说明 |
|------|------|
| `system_release.txt` | `/etc/openwrt_release` 与 `/etc/os-release` |
| `uname.txt` | `uname -a` |
| `dropbear_version.txt` | Dropbear 版本（若有） |
| `proc_mtd.txt` | `/proc/mtd` |
| `board_name.txt` / `model.txt` | 来自 `/tmp/sysinfo/`（若存在） |
| `dt_model.txt` | `/proc/device-tree/model`（若可读） |
| `opkg_list_installed.txt` | `opkg list-installed` 排序后完整列表 |
| `opkg_count.txt` | 上述列表行数（即包数量） |

在路由器上打包并拷回：

```sh
ssh root@192.168.1.1 'cd /tmp && tar czf oem-snapshot.tgz oem-snapshot-* && ls -la oem-snapshot.tgz'
scp root@192.168.1.1:/tmp/oem-snapshot.tgz .
```

解压后，可将其中文件 **合并或替换** 进 `oem-dt/`（与现有 `proc_mtd.txt`、`model.txt` 等对齐命名即可），并把 **`opkg_list_installed.txt` / `opkg_count.txt`** 一并纳入版本库，便于以后对比。

可选：指定输出目录（设备上可写路径）：

```sh
ssh root@192.168.1.1 "OEM_SNAPSHOT_DIR=/root/oem-snap sh -s" < oem-dt/collect-oem-snapshot.sh
```

## 设备树等（历史说明）

- `live.dts`、`dt_export/`、`dt_export.tgz`：来自当时现场的 DT 导出。
- `oem_probe.txt`：当时手工探测摘要（内核、Dropbear、MTD、`/lib/upgrade` 列表等）。
- `oem-upgrade/`：从设备拷贝的 `sysupgrade` / `platform.sh` 等片段，供对照升级逻辑。

若你更新了快照，建议在同一次提交里简短注明采集日期与固件来源（例如「OEM 出厂 Web 版本号」），便于与 `opkg` 列表对应。
