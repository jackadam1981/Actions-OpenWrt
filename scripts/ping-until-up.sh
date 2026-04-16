#!/usr/bin/env bash
# 刷机后计时：循环 ping 目标，直到首次成功，输出已等待秒数。
# 用法: ./scripts/ping-until-up.sh [目标IP或主机名] [间隔秒] [最长等待秒，0=不限制]
# 例:   ./scripts/ping-until-up.sh 192.168.1.1 1 300
#
# 说明：GNU/Linux 使用 ping -c 1 -W 1；Windows 原生环境请用同目录下的 ping-until-up.ps1。

set -euo pipefail

TARGET="${1:-192.168.1.1}"
INTERVAL="${2:-1}"
MAX_WAIT="${3:-0}"

case "$(uname -s 2>/dev/null || echo Unknown)" in
  MINGW*|MSYS*|CYGWIN*)
    ping_once() {
      local host="$1"
      ping -n 1 -w 2000 "$host" &>/dev/null
    }
    ;;
  Darwin)
    # 较新 macOS：-W 为每次探测等待毫秒数
    ping_once() {
      local host="$1"
      ping -c 1 -W 2000 "$host" &>/dev/null
    }
    ;;
  *)
    ping_once() {
      local host="$1"
      ping -c 1 -W 1 "$host" &>/dev/null
    }
    ;;
esac

echo "目标: $TARGET | 间隔: ${INTERVAL}s | 最长等待: $( [[ "$MAX_WAIT" -eq 0 ]] && echo '无限制' || echo "${MAX_WAIT}s" )"
echo "按 Ctrl+C 可随时停止。"
echo ""

START_TS=$(date +%s)

while true; do
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - START_TS))

  if [[ "$MAX_WAIT" -gt 0 && "$ELAPSED" -ge "$MAX_WAIT" ]]; then
    printf '[%6.1fs] 超时仍未 ping 通。\n' "$ELAPSED"
    exit 1
  fi

  if ping_once "$TARGET"; then
    printf '[%6.1fs] 已 ping 通: %s\n' "$ELAPSED" "$TARGET"
    exit 0
  fi

  printf '[%6.1fs] 无响应...\n' "$ELAPSED"
  sleep "$INTERVAL"
done
