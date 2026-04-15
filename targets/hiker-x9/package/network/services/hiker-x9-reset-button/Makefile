include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-reset-button
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-reset-button
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 reset button handler (LED + factory reset)
  PKGARCH:=all
endef

define Package/hiker-x9-reset-button/description
 Shared /etc/rc.button/reset for all Hiker X9 profiles: hold for reboot
  or factory reset, with red/blue LED feedback.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-reset-button/install
	$(INSTALL_DIR) $(1)/etc/rc.button
	$(INSTALL_BIN) ./files/reset $(1)/etc/rc.button/reset
endef

$(eval $(call BuildPackage,hiker-x9-reset-button))
