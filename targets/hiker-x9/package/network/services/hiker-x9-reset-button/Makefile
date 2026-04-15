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
 Shared reset button handler for all Hiker X9 profiles. Installs the handler
 under /usr/share and uses uci-defaults to copy it into /etc/rc.button/reset
 on first boot, avoiding ownership conflicts with base-files in APK builds.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-reset-button/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-reset-button
	$(INSTALL_BIN) ./files/reset $(1)/usr/share/hiker-x9-reset-button/reset

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/04-hiker-x9-reset-button $(1)/etc/uci-defaults/04-hiker-x9-reset-button
endef

$(eval $(call BuildPackage,hiker-x9-reset-button))
