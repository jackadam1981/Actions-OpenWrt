include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-standard-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-standard-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 standard profile default configuration
  DEPENDS:=+hiker-x9-reset-button
  PKGARCH:=all
endef

define Package/hiker-x9-standard-defaults/description
 First-boot banner, network (LAN 192.168.168.1), firewall zone hints,
 and LED for the standard (full router + LuCI + WiFi) image.
 Reset: hiker-x9-reset-button. See targets/README.md and oem-dt/
 collected snapshot for OEM alignment notes (not a 1:1 package copy).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-standard-defaults/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-standard
	$(INSTALL_DATA) ./files/banner $(1)/usr/share/hiker-x9-standard/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-standard $(1)/etc/uci-defaults/99-hiker-x9-standard

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/hiker-boot-metrics.init $(1)/etc/init.d/hiker-boot-metrics

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/99-hiker-boot-metrics.iface $(1)/etc/hotplug.d/iface/99-hiker-boot-metrics
endef

$(eval $(call BuildPackage,hiker-x9-standard-defaults))
