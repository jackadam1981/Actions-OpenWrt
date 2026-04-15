include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-p910nd-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-p910nd-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 p910nd profile default configuration (wired)
  DEPENDS:=+p910nd +hiker-x9-reset-button
  PKGARCH:=all
endef

define Package/hiker-x9-p910nd-defaults/description
 Banner, network, firewall, p910nd autostart and LED for the wired
 print-server profile. Reset: hiker-x9-reset-button.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-p910nd-defaults/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-p910nd
	$(INSTALL_DATA) ./files/banner $(1)/usr/share/hiker-x9-p910nd/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-p910nd $(1)/etc/uci-defaults/99-hiker-x9-p910nd
endef

$(eval $(call BuildPackage,hiker-x9-p910nd-defaults))
