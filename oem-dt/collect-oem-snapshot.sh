#!/bin/sh
# 在 OEM / OpenWrt 设备上执行（ash），导出版本与 opkg 清单等，便于同步到本仓库 oem-dt/。
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

BN=$(basename "$OUT")
echo "完成。包数量（opkg list-installed 行数）: $(cat "$OUT/opkg_count.txt")"
echo "请打包拷回 PC（在设备上执行）:"
echo "  cd $(dirname "$OUT") && tar czf ${BN}.tgz ${BN} && ls -la ${BN}.tgz"
echo "在 PC 上拉取:"
echo "  scp root@<路由器IP>:$(dirname "$OUT")/${BN}.tgz ."
