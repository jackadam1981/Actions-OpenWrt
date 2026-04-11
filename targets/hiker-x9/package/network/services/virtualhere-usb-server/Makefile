include $(TOPDIR)/rules.mk

PKG_NAME:=virtualhere-usb-server
PKG_VERSION:=4.8.6
PKG_RELEASE:=1

PKG_SOURCE:=vhusbdmipsel
PKG_SOURCE_URL:=https://www.virtualhere.com/sites/default/files/usbserver/
PKG_HASH:=4eecdf66cb69384076d87fc5a7d727c2efe90f7577ca582ed73c721a3390f51e
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_LICENSE:=Proprietary
PKG_MAINTAINER:=Cursor Agent
PKG_BUILD_FLAGS:=no-mips16

include $(INCLUDE_DIR)/package.mk

define Package/virtualhere-usb-server
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=USB Support
  TITLE:=VirtualHere USB Server for MIPS little-endian
  URL:=https://www.virtualhere.com/usb_server_software
  DEPENDS:=+libuci +libubox
endef

define Package/virtualhere-usb-server/description
 VirtualHere USB Server binary package for OpenWrt MIPS little-endian targets.
 It installs the upstream statically linked server, an init script and a UCI
 config file so the service can be managed on embedded devices.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/$(PKG_SOURCE) $(PKG_BUILD_DIR)/virtualhere-usb-server
	chmod 0755 $(PKG_BUILD_DIR)/virtualhere-usb-server
endef

define Build/Compile
endef

define Package/virtualhere-usb-server/conffiles
/etc/config/virtualhere-usb-server
/etc/virtualhere/config.ini
endef

define Package/virtualhere-usb-server/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/virtualhere-usb-server $(1)/usr/sbin/virtualhere-usb-server

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/virtualhere-usb-server.init $(1)/etc/init.d/virtualhere-usb-server

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/virtualhere-usb-server.config $(1)/etc/config/virtualhere-usb-server

	$(INSTALL_DIR) $(1)/etc/virtualhere
	$(INSTALL_CONF) ./files/config.ini $(1)/etc/virtualhere/config.ini
endef

$(eval $(call BuildPackage,virtualhere-usb-server))
