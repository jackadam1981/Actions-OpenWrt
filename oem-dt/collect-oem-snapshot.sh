#!/bin/sh
# 在 OEM / OpenWrt 设备上执行（ash），导出版本、opkg 清单与内核相关信息，便于同步到本仓库 oem-dt/。
# 用法（IP 按设备 LAN，当前 OEM 示例见 oem-dt/README.md）：
#   ssh root@192.168.168.1 'sh -s' < collect-oem-snapshot.sh
# 或上传到设备后：sh collect-oem-snapshot.sh
# 可选：OEM_SNAPSHOT_DIR=/root/snap sh collect-oem-snapshot.sh

set -u

TS=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "unknown")
OUT="${OEM_SNAPSHOT_DIR:-/tmp/oem-snapshot-$TS}"
mkdir -p "$OUT" || {
	echo "无法创建目录: $OUT" >&2
	exit 1
}

echo "写入: $OUT"

{
	echo "=== /etc/openwrt_release ==="
	cat /etc/openwrt_release 2>/dev/null || echo "(missing)"
	echo
	echo "=== /etc/os-release ==="
	cat /etc/os-release 2>/dev/null || echo "(missing)"
	if [ -r /usr/lib/os-release ]; then
		echo
		echo "=== /usr/lib/os-release ==="
		cat /usr/lib/os-release 2>/dev/null || true
		cp /usr/lib/os-release "$OUT/usr_lib_os_release.txt" 2>/dev/null || true
	fi
} >"$OUT/system_release.txt"

uname -a >"$OUT/uname.txt" 2>&1

{
	dropbear -V 2>&1 || true
} >"$OUT/dropbear_version.txt"

cat /proc/mtd >"$OUT/proc_mtd.txt" 2>&1 || echo "(missing)" >"$OUT/proc_mtd.txt"

# opkg 官方/自定义源（与 Chaos Calmer 等发行版、包索引 URL 对应）
if [ -r /etc/opkg/distfeeds.conf ]; then
	cp /etc/opkg/distfeeds.conf "$OUT/opkg_distfeeds.conf"
else
	echo "(missing /etc/opkg/distfeeds.conf)" >"$OUT/opkg_distfeeds.conf"
fi
if [ -r /etc/opkg/customfeeds.conf ]; then
	cp /etc/opkg/customfeeds.conf "$OUT/opkg_customfeeds.conf"
else
	echo "(missing /etc/opkg/customfeeds.conf)" >"$OUT/opkg_customfeeds.conf"
fi

# 常见 board/model 路径
for f in /tmp/sysinfo/board_name /tmp/sysinfo/model; do
	if [ -r "$f" ]; then
		bn=$(basename "$f")
		cp "$f" "$OUT/${bn}.txt"
	fi
done

if [ -r /proc/device-tree/model ]; then
	tr -d '\0' </proc/device-tree/model >"$OUT/dt_model.txt" 2>/dev/null || true
fi

if command -v opkg >/dev/null 2>&1; then
	opkg list-installed | sort >"$OUT/opkg_list_installed.txt"
	wc -l <"$OUT/opkg_list_installed.txt" | tr -d ' ' >"$OUT/opkg_count.txt"
else
	echo "(no opkg)" >"$OUT/opkg_list_installed.txt"
	echo "0" >"$OUT/opkg_count.txt"
fi

# --- kernel（运行中内核与模块；与 rootfs 包列表互补）---
cat /proc/version >"$OUT/proc_version.txt" 2>&1 || echo "(missing)" >"$OUT/proc_version.txt"
cat /proc/cmdline >"$OUT/proc_cmdline.txt" 2>&1 || echo "(missing)" >"$OUT/proc_cmdline.txt"
cat /proc/cpuinfo >"$OUT/proc_cpuinfo.txt" 2>&1 || echo "(missing)" >"$OUT/proc_cpuinfo.txt"

KVER=$(uname -r)
if [ -d "/lib/modules/$KVER" ]; then
	ls -la "/lib/modules/$KVER" >"$OUT/kernel_modules_dir_ls.txt" 2>&1 || true
	find "/lib/modules/$KVER" -name '*.ko' 2>/dev/null | sort >"$OUT/kernel_modules_ko_list.txt" || true
	wc -l <"$OUT/kernel_modules_ko_list.txt" 2>/dev/null | tr -d ' ' >"$OUT/kernel_modules_ko_count.txt" || echo "0" >"$OUT/kernel_modules_ko_count.txt"
else
	echo "(no /lib/modules/$KVER)" >"$OUT/kernel_modules_dir_ls.txt"
	: >"$OUT/kernel_modules_ko_list.txt"
	echo "0" >"$OUT/kernel_modules_ko_count.txt"
fi

if [ -r /proc/config.gz ]; then
	if zcat /proc/config.gz >"$OUT/kernel_config.txt" 2>/dev/null; then
		wc -l <"$OUT/kernel_config.txt" | tr -d ' ' >"$OUT/kernel_config_linecount.txt"
	else
		echo "(zcat /proc/config.gz failed)" >"$OUT/kernel_config.txt"
		echo "0" >"$OUT/kernel_config_linecount.txt"
	fi
else
	echo "(no /proc/config.gz; kernel likely built without CONFIG_IKCONFIG / CONFIG_IKCONFIG_PROC)" >"$OUT/kernel_config.txt"
	wc -l <"$OUT/kernel_config.txt" | tr -d ' ' >"$OUT/kernel_config_linecount.txt"
fi

dmesg 2>/dev/null | head -n 160 >"$OUT/dmesg_head.txt" || true

grep -E '^(kernel|kmod-)' "$OUT/opkg_list_installed.txt" 2>/dev/null | sort >"$OUT/opkg_kernel_kmod.txt" || : >"$OUT/opkg_kernel_kmod.txt"
wc -l <"$OUT/opkg_kernel_kmod.txt" 2>/dev/null | tr -d ' ' >"$OUT/opkg_kernel_kmod_count.txt" || echo "0" >"$OUT/opkg_kernel_kmod_count.txt"

BN=$(basename "$OUT")
echo "完成。包数量（opkg list-installed 行数）: $(cat "$OUT/opkg_count.txt")"
echo "内核模块 .ko 数量: $(cat "$OUT/kernel_modules_ko_count.txt")；kernel/kmod opkg 行数: $(cat "$OUT/opkg_kernel_kmod_count.txt")；kernel_config 行数: $(cat "$OUT/kernel_config_linecount.txt")"
echo "请打包拷回 PC（在设备上执行）:"
echo "  cd $(dirname "$OUT") && tar czf ${BN}.tgz ${BN} && ls -la ${BN}.tgz"
echo "在 PC 上拉取:"
echo "  scp -O root@<ROUTER_IP>:$(dirname "$OUT")/${BN}.tgz ."

exit 0
