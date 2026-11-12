# targets/ax3600-slub-debug — Xiaomi AX3600（调试变体）

## 与 `../ax3600-slub` 的关系

| 项 | `ax3600-slub` | `ax3600-slub-debug` |
| --- | --- | --- |
| `.config` | 本仓库那份 | **完全相同**（逐字节一致） |
| 内核二进制 | 同一份 | 同一份（配置没变） |
| DTB `bootargs-append` | ` root=/dev/ubiblock0_0` | ` root=/dev/ubiblock0_0 slub_debug=U slab_nomerge` |
| 用途 | 日常跑 | 定位泄漏期间刷 |

因为只差一个字符串，**内核与内核模块的 ABI 完全一致**，两个变体可以互相刷、模块不用换。

## 多了什么

- `slub_debug=U`：`store_user`，每个对象记录分配/释放的调用栈 →
  `/sys/kernel/slab/<cache>/alloc_calls`、`free_calls` 能看出**谁在泄漏**
- `slab_nomerge`：关闭 slab cache 合并，避免同类 cache 被并成 `:0000008` 这种匿名名，
  归因才准（合并只在启动时决定，运行时改不了）

代价：`U` 会给每个对象多存一份栈信息，512 MB 内存的机器要盯着 `MemAvailable`；
如果只想看某个 cache，可以改成 `slub_debug=U,kmalloc-256` 这种按 cache 指定。
`F`（redzone）/`Z`/`P`（poison）更重，只在确认是越界写/UAF 时再加。

## 刷写与回退

- 同样是整包 `sysupgrade`，配置默认保留（`/etc/config`）；`-n` 才会清空
- 回退：重新刷官方 `openwrt-25.12.x-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin`
- **AX3600 没有 A/B 分区**（`platform.sh` 强制 `flag_boot_rootfs 0`），刷坏需要 U-Boot tftp 或串口

## 产物

与 `ax3600-slub` 同名，`CONFIG_SLUG` 为 `ax3600-slub-debug`，artifact 名
`OpenWrt_firmware_ax3600-slub-debug`。

## 怎么跑

`only_targets` 填 `ax3600-slub-debug`（或 `ax3600-slub,ax3600-slub-debug` 一次编两个）。
