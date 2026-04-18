include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-minimal-ping-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-minimal-ping-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 minimal (ping-only): WAN disabled, stock LAN
  DEPENDS:=+hiker-x9-reset-button
  PKGARCH:=all
endef

define Package/hiker-x9-minimal-ping-defaults/description
 First boot only: if network.wan exists, set proto to none (avoids long udhcpc
 when no uplink). Does not change LAN (stock OpenWrt, typically 192.168.1.1).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-minimal-ping-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-minimal-ping $(1)/etc/uci-defaults/99-hiker-x9-minimal-ping
endef

$(eval $(call BuildPackage,hiker-x9-minimal-ping-defaults))
