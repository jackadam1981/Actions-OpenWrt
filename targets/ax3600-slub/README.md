# targets/ax3600-slub — Xiaomi AX3600（日常变体）

## 是什么

- 设备：Xiaomi AX3600，目标 `qualcommax / ipq807x`，profile `xiaomi_ax3600`
- 源码：仓库 `env.REPO_URL`（`openwrt/openwrt`）+ `env.REPO_BRANCH`（`openwrt-25.12` 分支 **HEAD**，不钉 commit）
- 与官方 25.12 的唯一实质差异：**内核多编了 SLUB 调试能力**，且**默认不开启**

```
CONFIG_KERNEL_SLUB_DEBUG=y      # 编译进内核：/proc/slabinfo、/sys/kernel/slab/*/objects、接受 slub_debug= 启动参数
CONFIG_KERNEL_KALLSYMS=y        # 栈回溯有符号名（官方构建是关的）
# CONFIG_KERNEL_SLUB_DEBUG_ON is not set   # 不用 ON，否则 512 MB 机器全程开调试
```

`Config-kernel.in` 原文对该项的描述：接受 `slub_debug` 内核参数、提供 cache 调试选项、
在 `/sys/kernel/slab/` 下暴露 **对象数量**、启用 `/proc/slabinfo`、OOM 时打印更多信息；
代价是「code size 明显增加」。

## 启动参数（重要）

AX3600 的 `bootargs` 由 U-Boot 传入，DTS 只有 `bootargs-append = " root=/dev/ubiblock0_0"`。
**没有** `fw_setenv bootargs` 这种运行时开关（U-Boot env 里没有该变量），
所以「按需开启 slub_debug」= 刷另一份把参数写进 DTB 的镜像，见 `../ax3600-slub-debug/`。

## 包集合

按现网 `/etc/apk/world` 的 77 条按**包名**对齐（丢弃 `=版本` 串）：

| 处理 | 条目 | 原因 |
| --- | --- | --- |
| 删除 | `base-files=…`、`kernel=…`、`libc=…` | 带 hash 的 pin，新版本必然对不上 |
| 删除 | `luci-app-openclash><…` | 第三方包，官方 feed 无；noarch、不涉 kmod，刷后用 apk 重装 |
| 互斥 | `dnsmasq` vs `dnsmasq-full` | 只留 full，显式 `# CONFIG_PACKAGE_dnsmasq is not set` |

不写 `CONFIG_ALL_KMODS` / `CONFIG_ALL_NONSHARED`（它们只出现在官方发布用的 `config.buildinfo`，
照抄会把全平台 kmod 都编一遍）。

## 已知副作用

内核配置一变，内核包版本串里的配置哈希就变（现网是 `6.12.112~327ce20f…`），
**官方 kmods 软件源里的包将无法安装**。所有 `kmod-*` 必须已编进镜像。

## 产物

`openwrt/bin/targets/qualcommax/ipq807x/`：

- `*xiaomi_ax3600-squashfs-sysupgrade.bin` — 刷机用
- `*xiaomi_ax3600-initramfs-factory.ubi` / `*-initramfs-uImage.itb` — 救援/免刷验证
- `COMMIT.txt` — 本次构建对应的源码 commit（workflow 写入）
- `sha256sums`、`config.buildinfo`

## 怎么跑

手动触发 `OpenWrt Builder`，**`only_targets` 填 `ax3600-slub`**
（默认值是 `dir-505,hiker-x9`，不填不会编本目标）。

## 校验

构建日志里 `=== DIFFCONFIG BEGIN/END ===` 之间是本次实际的 `diffconfig` 输出。
`expected.diffconfig` 是断言基线，已由 2026-11-12 首次构建的实测输出整段替换；
若日后有意改动配置，用同一段日志整段覆盖该文件，否则构建会在该 step 硬失败。
硬断言（缺一个就 fail）包括：`KERNEL_SLUB_DEBUG=y`（查 diffconfig）、`KERNEL_KALLSYMS=y`（查 `.config`，
默认即 y 的符号不会出现在 diffconfig 里）、`KERNEL_SLUB_DEBUG_ON` 不存在、`ALL_KMODS` 不存在、
`dnsmasq-full=y` 且 `dnsmasq` 不存在。
