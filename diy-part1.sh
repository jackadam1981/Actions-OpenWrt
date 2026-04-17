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
FEED_NAME=custom_devices
FEED_URL=https://github.com/jackadam1981/openwrt-custom-devices.git
grep -qE "^src-(git|link)[[:space:]]+${FEED_NAME}[[:space:]]" feeds.conf.default 2>/dev/null || \
  echo "src-git ${FEED_NAME} ${FEED_URL}" >>feeds.conf.default
