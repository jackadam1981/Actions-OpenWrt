include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-virtualhere-defaults
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-virtualhere-defaults
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 VirtualHere default configuration
  DEPENDS:=+virtualhere-usb-server
  PKGARCH:=all
endef

define Package/hiker-x9-virtualhere-defaults/description
 Hiker X9 defaults for the VirtualHere profile, including banner, first-boot
 network setup and reset button behavior.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-virtualhere-defaults/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-virtualhere
	$(INSTALL_DATA) ./files/banner $(1)/usr/share/hiker-x9-virtualhere/banner
	$(INSTALL_BIN) ./files/reset $(1)/usr/share/hiker-x9-virtualhere/reset

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-hiker-x9-virtualhere $(1)/etc/uci-defaults/99-hiker-x9-virtualhere
endef

$(eval $(call BuildPackage,hiker-x9-virtualhere-defaults))
