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

# 不再使用 openwrt-custom-devices（targets / custom_devices）feed；硬件与机型由本仓 targets/<name>/ 下 overlay 合并进源码树（见 diy-part2.sh）。
# self-hosted 持久工作区里可能仍留有旧行，这里删掉以免干扰 ./scripts/feeds。
if [ -f feeds.conf.default ]; then
  sed -i.bak -E \
    -e '\#^src-(git|link)[[:space:]]+targets[[:space:]].*jackadam1981/openwrt-custom-devices#d' \
    -e '\#^src-(git|link)[[:space:]]+custom_devices[[:space:]]#d' \
    feeds.conf.default || true
fi
