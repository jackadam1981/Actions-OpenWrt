include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-minimal-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-minimal-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 minimal profile default configuration
  DEPENDS:=+hiker-x9-reset-button
  PKGARCH:=all
endef

define Package/hiker-x9-minimal-defaults/description
 Banner, first-boot network, firewall and LED for the minimal (wired)
 print-server base image. Reset button: package hiker-x9-reset-button.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-minimal-defaults/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-minimal
	$(INSTALL_DATA) ./files/banner $(1)/usr/share/hiker-x9-minimal/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-minimal $(1)/etc/uci-defaults/99-hiker-x9-minimal

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/hiker-boot-metrics.init $(1)/etc/init.d/hiker-boot-metrics

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/99-hiker-boot-metrics.iface $(1)/etc/hotplug.d/iface/99-hiker-boot-metrics
endef

$(eval $(call BuildPackage,hiker-x9-minimal-defaults))
