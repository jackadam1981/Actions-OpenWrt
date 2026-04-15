include $(TOPDIR)/rules.mk

PKG_NAME:=hiker-x9-breed-autoflash
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/hiker-x9-breed-autoflash
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Hiker X9 first-boot auto flash Breed bootloader
  DEPENDS:=+mtd
  PKGARCH:=all
endef

define Package/hiker-x9-breed-autoflash/description
 First boot script that backs up u-boot/u-boot-env/factory and flashes
 Breed (RT5350) into the u-boot partition automatically if the current
 bootloader is not already Breed.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/hiker-x9-breed-autoflash/install
	$(INSTALL_DIR) $(1)/usr/share/hiker-x9-breed
	$(INSTALL_DATA) ./files/breed-rt5350-blank.uimage $(1)/usr/share/hiker-x9-breed/breed-rt5350-blank.uimage

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/05-breed-autoflash $(1)/etc/uci-defaults/05-breed-autoflash
endef

$(eval $(call BuildPackage,hiker-x9-breed-autoflash))

