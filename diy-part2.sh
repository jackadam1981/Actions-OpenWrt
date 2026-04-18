#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds, 已加载 .config)
# 在 Actions 中运行时：应用 targets/<name> 下的 target/、package/、etc/ 覆盖（不依赖任何 targets feed）。
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

apply_target_overlay() {
  local TD="$1"
  [ -n "$TD" ] && [ -d "$TD" ] || return 0
  if [ -d "$TD/target" ]; then
    rsync -a "$TD/target/" target/
  fi
  if [ -d "$TD/package" ]; then
    rsync -a "$TD/package/" package/
  fi
  if [ -d "$TD/etc" ]; then
    mkdir -p package/base-files/files/etc
    rsync -a "$TD/etc/" package/base-files/files/etc/
  fi
}

# 应用当前 target 的 target/、package/、etc/ 覆盖（矩阵编译时 TARGET_NAME/TARGETS_DIR 由工作流传入）
if [ -n "${TARGET_NAME}" ] && [ -n "${TARGETS_DIR}" ] && [ -n "${GITHUB_WORKSPACE}" ]; then
  # baseline-only：.config 在 _hiker-x9-baseline-only/；hiker.mk 里 baseline = 上游小路由默认包 +urngd，overlay 仍用 hiker-x9/
  if [ "${TARGET_NAME}" = "_hiker-x9-baseline-only" ]; then
    apply_target_overlay "${GITHUB_WORKSPACE}/${TARGETS_DIR}/hiker-x9"
  fi
  apply_target_overlay "${GITHUB_WORKSPACE}/${TARGETS_DIR}/${TARGET_NAME}"

  # 某些设备通过额外的 image/*.mk 扩展 profile，需要显式接到子 target 定义中。
  if [ -f target/linux/ramips/image/hiker.mk ] && [ -f target/linux/ramips/image/rt305x.mk ]; then
    if ! grep -q 'target/linux/ramips/image/hiker.mk' target/linux/ramips/image/rt305x.mk; then
      printf '\ninclude $(TOPDIR)/target/linux/ramips/image/hiker.mk\n' >> target/linux/ramips/image/rt305x.mk
    fi
  fi
fi

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate
