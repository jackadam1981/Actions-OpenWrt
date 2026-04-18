# 从 bin 产物与源码推断刷机路径（本仓实施记录）

本仓库为 CI 构建脚手架，**工作区内通常没有** `bin/targets/`（产物在 Actions Artifact 或 Release）。下表根据各 `targets/<name>/.config` 与 overlay，归纳**构建成功后**应出现的镜像类型，以及如何在本仓与上游 OpenWrt 源码中追溯分区与升级逻辑。

**刷机后指示灯**：首次启动或写入未完成时，**电源旁红灯常会闪烁**。**请等到红灯不再闪烁**（常亮或熄灭，以硬件为准）**后再视为正常可用**；闪烁期间请勿反复断电，以免损坏固件或分区。

**首启耗时参考（本仓实测）**：刷 **`hiker_x9-minimal`（黄金底 / mini）** 后，LAN 侧用 [`scripts/ping-until-up.ps1`](../scripts/ping-until-up.ps1) 计时至首次 **ICMP ping 通** 约 **680 s**（约 11 min；非基准值，见 [targets/README.md](../targets/README.md) 说明）。

---

## 1. 预期产物（`bin/targets/...`）

| 目标目录 | OpenWrt target | 设备 / profile | 典型文件名模式 | 说明 |
|----------|----------------|----------------|----------------|------|
| [targets/hiker-x9](../targets/hiker-x9) | `ramips` / `rt305x` | 多个 Device（含 **`hiker_x9-minimal`**、**`hiker_x9-standard`**、**`hiker_x9-minimal-baseline`**、**`hiker_x9-factory`** 及打印 / VirtualHere 等 profile，以 [hiker.mk](../targets/hiker-x9/target/linux/ramips/image/hiker.mk) 为准） | `*-hiker_x9-*-squashfs-sysupgrade.bin`；**`hiker_x9-factory` 另产 `*-factory.bin`** | 自定义板，见 `hiker.mk`；`IMAGE_SIZE := 7872k`。**从官版 / 原厂 Web 或恢复环境首次刷入**：请使用 **`hiker_x9-factory` 对应的 `factory.bin`**（本仓按实机流程验证，**官版可直接刷入该 factory**）。已运行本固件后，各功能 profile 仍以 **`sysupgrade.bin`** 升级为主。 |
| [targets/dir-505](../targets/dir-505) | `ath79` / `generic` | `dlink_dir-505` | `*-dlink_dir-505-squashfs-sysupgrade.bin`、`*-dlink_dir-505-initramfs-kernel.bin` | 上游设备；`generic.mk` 中仅 `IMAGE_SIZE`，默认生成 sysupgrade / initramfs（见下文上游引用）。 |
| [targets/x86-64](../targets/x86-64) | `x86` / `64` | `generic` | `*-ext4-combined.img.gz` 等 | 虚拟机 / PC；刷写方式为磁盘镜像或 `sysupgrade.tar`，与路由器 NOR SPI 流程不同。 |

**命名规律**：`{distribution}-{ver}-{target}-{subtarget}-{board}-squashfs-sysupgrade.bin`（具体前缀随发行版与版本变化）。

---

## 2. 源码追踪（本仓 + 上游）

### 2.1 Hiker X9（本仓可完整看到）

| 内容 | 路径 |
|------|------|
| 分区与 Flash | [rt5350_hiker_x9.dtsi](../targets/hiker-x9/target/linux/ramips/dts/rt5350_hiker_x9.dtsi)：`u-boot` 0x0–0x30000，`u-boot-env` 0x30000–0x40000，`factory`（校准/MAC/EEPROM）0x40000–0x50000，`firmware`（`denx,uimage`）0x50000–0x7FFFFF（与 `IMAGE_SIZE 7872k` 对应固件可用空间）。 |
| 设备 profile 与包列表 | [hiker.mk](../targets/hiker-x9/target/linux/ramips/image/hiker.mk)：`Device/hiker_*`、`SUPPORTED_DEVICES`（影响 sysupgrade 校验的 board name）。 |
| 将 hiker.mk 接入 rt305x | [diy-part2.sh](../diy-part2.sh) 在存在 `target/linux/ramips/image/hiker.mk` 时向 `rt305x.mk` 追加 `include .../hiker.mk`。 |

**原厂镜像**：实机可验证厂商固件为 **OpenWrt 衍生**（例如 rootfs 中出现典型 OpenWrt 布局或版本信息）。若厂商**开放 SSH**（或可自行开启），多数排查**不必依赖串口 / UART**：可在 shell 里用 `logread -f`、`dmesg`、`cat /proc/mtd`、`block info`、`uci show`、`ls /lib/upgrade`、`sysupgrade -h` 等对照分区与升级脚本约束；失败时日志往往在 `logread` 与 LuCI/命令行升级输出中即可复现。串口仍是 **U-Boot 阶段、内核早期 panic、SSH 不可达** 时的兜底手段。  
上述便利**不**等同于「任意 profile 的 `sysupgrade.bin` 都可被官版恢复页接受」。**例外**：本仓 **`hiker_x9-factory` 生成的 `factory.bin` 设计为供官版首刷**；其它 profile 的 `sysupgrade.bin` 仍按运行中系统升级使用。

**从原厂 SSH 提取运行中设备树**：若内核启用了 OF（常见），根下会有 **`/proc/device-tree`**。可先 `ls /proc/device-tree`，并用 `hexdump -C /proc/device-tree/compatible | head` 或 `strings /proc/device-tree/compatible` 查看 `compatible`（属性多为 **小端 4 字节一单元的字符串**，直接 `cat` 可能带不可见字符）。  
生成可读的 **`.dts` 草稿**（与源码树里的 `.dts` 不等价：无 `#include`/标签，phandle 为数字）任选其一：

1. **设备上**已装 **`dtc`**（OpenWrt 常为包 `dtc` / `device-tree-compiler`）：  
   `dtc -I fs -O dts -o /tmp/live.dts /proc/device-tree`  
2. **设备无 `dtc`**：把 `/proc/device-tree` 打成包拷到电脑再反编译。注意该目录里**大量是符号链接**，普通 `tar czf … -C /proc device-tree`往往只打进链接本身，**体积会异常小（例如仅百余字节）**，解压后也不适合直接给 `dtc -I fs` 用。请改用**跟随链接**再打包，并在打包后粗查条目数：  
   - **GNU tar**：`tar --dereference -czf /tmp/dt.tgz -C /proc device-tree`（勿省略 `--dereference`/`-h`，否则归档会过小）。  
   - **BusyBox tar**（常见 OpenWrt）：若支持跟链接，一般为 **`tar czf /tmp/dt.tgz -h -C /proc device-tree`**（`-h` 须在创建模式下生效；以 `tar --help` 为准）。  
   - **仍异常时**：先复制成「全是普通文件」的树再打包：  
     `cp -rL /proc/device-tree /tmp/dt_export && tar czf /tmp/dt.tgz -C /tmp dt_export`  
   打包后可用 `gzip -dc /tmp/dt.tgz | tar tv | wc -l` 看条目数（正常应为**成百上千**，不是个位数）。下载解压后，在电脑上对目录执行： `dtc -I fs -O dts -o live.dts <解压出的 device-tree 或 dt_export 目录>`。  
   若 `/proc/device-tree` 不存在，多为非 DT 引导或极精简内核；再考虑从 **`firmware` MTD** 解 `uImage`/内核镜像，在电脑上对尾部 **DTB** 用 `fdtdump`/`dtc` 或 `scripts/extract-dtb` 一类工具抽取。

**上游（需在克隆的 OpenWrt 树中查看）**

- `target/linux/ramips/image/rt305x.mk`：默认镜像配方（如 `append-kernel`、`append-rootfs`、`pad-rootfs` 等）。
- `package/base-files/files/lib/upgrade/do_stage2`：调用 `platform_do_upgrade`（若存在）或 `default_do_upgrade`。
- 在完整树中搜索 `platform_do_upgrade` / `ramips`：各子 target 可能在 `target/linux/ramips/.../base-files/lib/upgrade/` 下提供平台脚本（路径随 OpenWrt 版本略有调整，以你检出的 tag 为准）。

### 2.2 D-Link DIR-505（上游设备定义摘录）

上游 `openwrt-23.05` [target/linux/ath79/image/generic.mk](https://github.com/openwrt/openwrt/blob/openwrt-23.05/target/linux/ath79/image/generic.mk) 中与 DIR-505 相关片段为：

```makefile
define Device/dlink_dir-505
 SOC := ar9330
 DEVICE_VENDOR := D-Link
 DEVICE_MODEL := DIR-505
 IMAGE_SIZE := 7680k
 DEVICE_PACKAGES := kmod-usb-chipidea2
 SUPPORTED_DEVICES += dir-505-a1
endef
TARGET_DEVICES += dlink_dir-505
```

未在该片段中单独声明 `factory.bin` 时，**首次从原厂刷机**常依赖 Wiki 所述的 **D-Link Recovery（上传特定格式固件）** 或 **initramfs + TFTP/UART**，与当前生成的 `sysupgrade.bin` 是否同一文件需对照 Wiki 与历史 `ar71xx`/`ath79` 镜像说明。

**本仓实测（单点记录，供粗预期）**：经 **U-Boot / D-Link Recovery** 刷入 **OpenWrt 官方 factory** 包后，以本机首次 **ICMP ping 通**（刷写完成、PC 接 LAN 后按常规地址探测）计时约 **86.6 s**，同条件下可粗预期 **约 90 s 以内**（硬件 revision、镜像版本、上联与网线因素会带来偏差）。

### 2.3 x86_64

关注 `target/linux/x86/image/Makefile` 与 `CONFIG_TARGET_ROOTFS_EXT4FS` 等选项；刷机为磁盘/IMG，与嵌入式 NOR 流程不同。

---

## 3. Wiki / 社区对照（原厂限制与入口）

> 注：`openwrt.org` 部分页面启用了反自动化访问；下列为公开镜像与文档中的**共识性**描述，刷机前请以你设备硬件版本为准。

| 设备 | 首次安装 / 恢复 | OpenWrt 已运行后 |
|------|-----------------|------------------|
| **DIR-505** | 常见：**按住 Reset 上电**进入恢复页（PC 设静态 IP，如 `192.168.0.x`），浏览器访问 `http://192.168.0.1` 上传固件；不同硬件 revision（A1 / LA1 等）需确认与 `SUPPORTED_DEVICES` 一致。 | `sysupgrade` 或 LuCI 上传 `*-sysupgrade.bin`。 |
| **Hiker X9** | **官版 / 原厂仍在时**：优先用 CI 产物里 **`hiker_x9-factory` 的 `factory.bin`** 按厂商 Web 或恢复页上传（**官版可直接刷入该 factory**）。救砖、无 Web 时仍可考虑 **TFTP / 串口** 等。若**原厂系统可 SSH**，也可在运行中对照 `/lib/upgrade`、`sysupgrade`、MTD 与 DTS 分区。其它 profile 的 **`sysupgrade.bin` 不宜假定**能被官版恢复页接受。 | 已在本固件上运行时，用对应 profile 的 **`sysupgrade.bin`** 升级。 |

**原厂侧常无法仅从 OpenWrt bin 推断**：签名校验、OEM 头、恢复页只接受特定封装、大小限制等。除拆包与对照 Wiki 外，**在仍为原厂 OpenWrt 衍生系统且 SSH 可用时**，以运行中日志与升级脚本为主、串口为辅；仅当 **SSH 不可用或问题出在 Bootloader/极早期启动** 时，串口 log、FCC 资料或社区实刷记录才更显必要。

---

## 4. Hex 分析示例（DIR-505 `sysupgrade.bin` 前 512 字节）

以下样本来自官方构建  
`openwrt-23.05.5-ath79-generic-dlink_dir-505-squashfs-sysupgrade.bin` 的 **字节 0–511**（与你在 Linux 上执行 `curl -r 0-511 -o sample.bin <url>` 再 `xxd sample.bin` 等价）。

**前 256 字节（十六进制摘录，每行 16 字节）**：

```
00000000  27 05 19 56 fe 3d 77 83 66 f1 60 66 00 23 ab 39  |'..V.=w.f.`f.#.9|
00000010  80 06 00 00 80 06 00 00 b0 49 8a 90 05 05 02 03  |.........I......|
00000020  4d 49 50 53 20 4f 70 65 6e 57 72 74 20 4c 69 6e  |MIPS OpenWrt Lin|
00000030  75 78 2d 35 2e 31 35 2e 31 36 37 00 00 00 00 00  |ux-5.15.167.....|
00000040  6d 00 00 80 00 9f 8a 77 00 00 00 00 00 00 00 6f  |m......w.......o|
00000050  fd ff ff a3 b7 7f 4c 3d ea 52 e4 f6 ca 65 0e 23  |......L=.R...e.#|
00000060  74 35 04 70 4b 8b 3d 2a 28 4d 3a 72 7a 83 2c 22  |t5.pK.=*(M:rz.,"|
00000070  ff e5 6f 51 66 db 5a 5d 03 fb 74 11 90 42 20 71  |..oQf.Z]..t..B q|
00000080  af 61 7d 83 f9 7b 76 5a 5b 6f e8 45 4a a8 0e a9  |.a}..{vZ[o.EJ...|
00000090  e5 da ff e1 a8 fc 48 0a 13 b7 99 36 0f a2 58 7a  |......H....6..Xz|
000000a0  b5 c6 ab ef 09 f7 3d eb a7 78 00 2a e0 5f eb 08  |......=..x.*._..|
000000b0  48 7b e8 67 32 af 2b 36 e9 c7 33 84 41 86 fa c6  |H{.g2.+6..3.A...|
000000c0  95 dd dc 46 1f 2a 45 d6 d2 9d 2d e5 d7 85 b6 ed  |...F.*E...-.....|
000000d0  cd ab e3 cf 47 87 06 e3 3f e6 5c c2 28 41 1b 38  |....G...?.\.(A.8|
000000e0  db a6 5a 13 41 59 78 f7 1b 5a 7e 92 00 2d 4e 60  |..Z.AYx..Z~..-N`|
000000f0  4e a9 c3 7c 2e 2a 86 77 6f b6 e6 28 ef 72 d7 f4  |N..|.*.wo..(.r..|
```

**要点解读**：

- 开头为 **设备/镜像封装头**（魔数与长度因 target 的 `append-kernel` / `mkimage` 链而异，不是单一固定 “OpenWrt” 字符串）。
- 偏移约 **0x1C–0x34** 附近出现可打印 ASCII：`MIPS OpenWrt Linux-5.15.167`，表明其后（或重叠区域）包含 **内核镜像元数据**（与 ath79 MIPS 内核打包一致）。
- **不能**仅凭前 512 字节判断整文件是否为 OEM 恢复页可接受的 factory 封装；需对照 `generic.mk` 中该设备的 `IMAGES` / `IMAGE/xxx` 配方与 Wiki 要求。

**建议命令（在 Linux / macOS 或 WSL）**：

```sh
# 在仓库根目录，固件路径按实际 Artifact 解压位置调整
scripts/dump-firmware-header.sh ./openwrt-*-sysupgrade.bin 512
file ./openwrt-*-sysupgrade.bin
strings -n 8 ./openwrt-*-sysupgrade.bin | head
binwalk -e ./openwrt-*-sysupgrade.bin   # 若已安装，查看嵌套段
```

---

## 5. 与本仓 CI 的衔接

1. 在 Actions 日志或 Artifact 中确认实际生成的文件名。  
2. 将文件名中的 **board 名** 对应到本仓 `targets/<name>/.config` 中的 `CONFIG_TARGET_*_DEVICE_*`。  
3. 对 **hiker-x9**：直接打开本仓 [dts](../targets/hiker-x9/target/linux/ramips/dts/) 与 [hiker.mk](../targets/hiker-x9/target/linux/ramips/image/hiker.mk)。  
4. 对 **dir-505 / x86**：在检出的 OpenWrt 同版本源码中打开对应 `image/*.mk` 与 `dts`。  
5. 刷机操作以 **OpenWrt Wiki（或旧 Wiki 镜像）+ 硬件版本** 为最终依据。

---

## 参考链接

- OpenWrt 旧 Wiki（DIR-505）：https://wiki.openwrt.org/toh/d-link/dir-505  
- OpenWrt 源码（ath79 generic 设备）：https://github.com/openwrt/openwrt/tree/master/target/linux/ath79  
- GitHub Node 20 弃用说明（与工作流无关，仅供 CI 维护者）：https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
