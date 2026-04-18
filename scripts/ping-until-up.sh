#!/usr/bin/env bash
# 刷机后计时：循环 ping 目标，直到首次成功，输出已等待秒数。
# 用法: ./scripts/ping-until-up.sh [目标IP] [间隔秒] [最长等待秒，0=不限制] [可选: TCP端口，如80需本机有 nc]
# 例:   ./scripts/ping-until-up.sh 192.168.1.1 1 300
# 例:   ./scripts/ping-until-up.sh 192.168.1.1 1 0 80
#
# 说明：GNU/Linux 使用 ping -c 1 -W 1；Windows 原生环境请用同目录下的 ping-until-up.ps1。

set -euo pipefail

TARGET="${1:-192.168.1.1}"
INTERVAL="${2:-1}"
MAX_WAIT="${3:-0}"
TCP_PORT="${4:-0}"
MAX_WAIT_TCP="${5:-600}"

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

echo "目标: $TARGET | 间隔: ${INTERVAL}s | 最长等待: $( [[ "$MAX_WAIT" -eq 0 ]] && echo '无限制' || echo "${MAX_WAIT}s" )$( [[ "$TCP_PORT" =~ ^[0-9]+$ ]] && [[ "$TCP_PORT" -gt 0 ]] && echo " | ping 通后探测 TCP ${TCP_PORT}（需 nc）" || true )"
echo "按 Ctrl+C 可随时停止。"
echo ""

tcp_open() {
  local host="$1" port="$2"
  command -v nc >/dev/null 2>&1 || return 1
  nc -z -w 2 "$host" "$port" 2>/dev/null
}

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
    if [[ "$TCP_PORT" =~ ^[0-9]+$ ]] && [[ "$TCP_PORT" -gt 0 ]]; then
      if ! command -v nc >/dev/null 2>&1; then
        echo "未安装 nc，跳过 TCP 探测。请安装 netcat 或改用 ping-until-up.ps1 -ProbeTcpPort ${TCP_PORT}"
        exit 0
      fi
      TCP_START_TS=$(date +%s)
      while true; do
        NOW_TS=$(date +%s)
        ELAPSED=$((NOW_TS - START_TS))
        TCP_WAIT=$((NOW_TS - TCP_START_TS))
        if [[ "$MAX_WAIT_TCP" -gt 0 && "$TCP_WAIT" -ge "$MAX_WAIT_TCP" ]]; then
          printf '[%6.1fs] TCP %s 超时（ping 后已等 %ss）\n' "$ELAPSED" "$TCP_PORT" "$TCP_WAIT"
          exit 1
        fi
        if tcp_open "$TARGET" "$TCP_PORT"; then
          GAP=$((NOW_TS - TCP_START_TS))
          printf '[%6.1fs] TCP 端口 %s 可连（与 ping 同一计时起点；ping 后 %ss）\n' "$ELAPSED" "$TCP_PORT" "$GAP"
          exit 0
        fi
        printf '[%6.1fs] TCP %s 未就绪...\n' "$ELAPSED" "$TCP_PORT"
        sleep "$INTERVAL"
      done
    fi
    exit 0
  fi

  printf '[%6.1fs] 无响应...\n' "$ELAPSED"
  sleep "$INTERVAL"
done
