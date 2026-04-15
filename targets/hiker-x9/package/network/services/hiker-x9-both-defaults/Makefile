include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-both-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-both-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 p910nd + VirtualHere default configuration
  DEPENDS:=+virtualhere-usb-server +p910nd +hiker-x9-reset-button
  PKGARCH:=all
endef

define Package/hiker-x9-both-defaults/description
 First-boot banner, network, firewall and VirtualHere for the wired
 "both" profile. Reset: hiker-x9-reset-button.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-both-defaults/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-both
	$(INSTALL_DATA) ./files/banner $(1)/usr/share/hiker-x9-both/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-both $(1)/etc/uci-defaults/99-hiker-x9-both
endef

$(eval $(call BuildPackage,hiker-x9-both-defaults))
