include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-p910nd-wifi-lite-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-p910nd-wifi-lite-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 p910nd + WiFi (lite) profile default configuration
  DEPENDS:=+p910nd +hiker-x9-reset-button
  PKGARCH:=all
endef

define Package/hiker-x9-p910nd-wifi-lite-defaults/description
 Banner, network, firewall, wireless, p910nd autostart and LED for
 the p910nd + WiFi (lite) profile. Reset: hiker-x9-reset-button.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-p910nd-wifi-lite-defaults/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-p910nd-wifi-lite
	$(INSTALL_DATA) ./files/banner $(1)/usr/share/hiker-x9-p910nd-wifi-lite/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-p910nd-wifi-lite $(1)/etc/uci-defaults/99-hiker-x9-p910nd-wifi-lite
endef

$(eval $(call BuildPackage,hiker-x9-p910nd-wifi-lite-defaults))

