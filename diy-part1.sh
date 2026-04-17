#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
# echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
# echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
# 自定义设备 feed（勿用名 targets：与上游 feeds.conf.default 中的 targets feed 冲突）
# 兼容 self-hosted “不清理目录”：历史上可能已追加过旧的 `targets` 名称，需要先清掉以避免重复。
FEED_NAME=custom_devices
FEED_URL=https://github.com/jackadam1981/openwrt-custom-devices.git

# 仅删除指向 openwrt-custom-devices 的旧 targets 行，避免误删上游可能启用的 openwrt/targets feed。
if [ -f feeds.conf.default ]; then
  sed -i.bak -E '\#^src-(git|link)[[:space:]]+targets[[:space:]].*(openwrt-custom-devices\.git|openwrt-custom-devices)#d' feeds.conf.default || true
fi

grep -qE "^src-(git|link)[[:space:]]+${FEED_NAME}[[:space:]]" feeds.conf.default 2>/dev/null || \
  echo "src-git ${FEED_NAME} ${FEED_URL}" >>feeds.conf.default
