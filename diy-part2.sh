#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds, 已加载 .config)
# 在 Actions 中运行时：会安装 targets feed 的 TARGET，并应用 targets/<name>/etc 覆盖。
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 安装 targets feed 中的 TARGET 包（若已启用 targets feed；列表失败或无 TARGET 时不报错退出）
list_targets() { ./scripts/feeds list -r targets 2>/dev/null | awk '/^TARGET:/ {print $2}' || true; }
for t in $(list_targets); do
  [ -n "$t" ] && ./scripts/feeds install -p targets -f "$t" || true
done

# 应用当前 target 的 etc/ 覆盖（矩阵编译时 TARGET_NAME/TARGETS_DIR 由工作流传入）
if [ -n "${TARGET_NAME}" ] && [ -n "${TARGETS_DIR}" ] && [ -n "${GITHUB_WORKSPACE}" ]; then
  TD="${GITHUB_WORKSPACE}/${TARGETS_DIR}/${TARGET_NAME}"
  if [ -d "$TD/etc" ]; then
    mkdir -p package/base-files/files/etc
    rsync -a "$TD/etc/" package/base-files/files/etc/
  fi
fi

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate
