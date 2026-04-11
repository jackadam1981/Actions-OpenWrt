#!/usr/bin/env sh
# Dump first N bytes of a firmware image (for comparing with OpenWrt image recipes).
# Usage: dump-firmware-header.sh <file> [bytes]
# Example: dump-firmware-header.sh ./openwrt-*-sysupgrade.bin 512

set -eu
f=${1:?usage: dump-firmware-header.sh <file> [bytes]}
n=${2:-512}

if [ ! -f "$f" ]; then
  echo "not a file: $f" >&2
  exit 1
fi

echo "== file =="
file "$f" || true
echo
echo "== hexdump (first $n bytes) =="
head -c "$n" "$f" | hexdump -C
