# Hiker RT5350 Device Profiles

define Device/hiker_hiker-common
	SOC := rt5350
	IMAGE_SIZE := 7872k
	DEVICE_VENDOR := Hiker
endef

# Strip unused router stack userland during build (not at first boot).
# Keep firewall packages (you said firewall is still useful).
HIKER_X9_STRIP := \
	-ppp -ppp-mod-pppoe \
	-dnsmasq -odhcpd-ipv6only -odhcp6c \
	-kmod-ppp -kmod-pppoe -kmod-pppox

define Device/hiker_x9-minimal
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Minimal
	DEVICE_DTS := rt5350_hiker_x9-minimal
	SUPPORTED_DEVICES := hiker,x9-minimal hiker,x9 HIKER
	# Golden base image: wired LAN only + LuCI (zh). Strip WiFi/AP userspace from
	# target defaults (same -wpad-basic-mbedtls pattern as WiFi profiles).
	DEVICE_PACKAGES := \
		luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		hiker-x9-minimal-defaults \
		urngd \
		-wpad-basic-mbedtls \
		-iw -iwinfo
endef
TARGET_DEVICES += hiker_x9-minimal

define Device/hiker_x9-minimal-baseline
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Minimal (baseline)
	DEVICE_DTS := rt5350_hiker_x9-minimal
	SUPPORTED_DEVICES := hiker,x9-minimal-baseline hiker,x9 HIKER
	# 上游默认栈 + urngd（减轻首启 dropbearkey 等因熵不足变慢）。
	DEVICE_PACKAGES := urngd
endef
TARGET_DEVICES += hiker_x9-minimal-baseline

define Device/hiker_x9-factory
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Factory
	DEVICE_DTS := rt5350_hiker_x9-factory
	SUPPORTED_DEVICES := hiker,x9-factory hiker,x9 HIKER
	# Factory helper image: include Breed auto-flash tooling.
	DEVICE_PACKAGES := \
		luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		hiker-x9-breed-autoflash \
		hiker-x9-minimal-defaults \
		urngd \
		-wpad-basic-mbedtls \
		-iw -iwinfo
	IMAGES += factory.bin
	IMAGE/factory.bin := $$(sysupgrade_bin) | check-size
endef
TARGET_DEVICES += hiker_x9-factory

define Device/hiker_x9-p910nd
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print
	DEVICE_DTS := rt5350_hiker_x9-p910nd
	SUPPORTED_DEVICES := hiker,x9-print hiker,x9 HIKER
	DEVICE_PACKAGES := luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer \
		hiker-x9-p910nd-defaults
endef
TARGET_DEVICES += hiker_x9-p910nd

define Device/hiker_x9-p910nd-wifi
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print WiFi
	DEVICE_DTS := rt5350_hiker_x9-p910nd-wifi
	SUPPORTED_DEVICES := hiker,x9-p910nd-wifi hiker,x9 HIKER
	DEVICE_PACKAGES := -wpad-basic-mbedtls luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer \
		hiker-x9-p910nd-wifi-defaults \
		kmod-mac80211 kmod-rt2800-lib kmod-rt2800-mmio kmod-rt2800-soc \
		kmod-rt2x00-lib kmod-rt2x00-mmio \
		wpad-mbedtls iw iwinfo
endef
TARGET_DEVICES += hiker_x9-p910nd-wifi

define Device/hiker_x9-p910nd-wifi-lite
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print WiFi (lite)
	DEVICE_DTS := rt5350_hiker_x9-p910nd-wifi
	SUPPORTED_DEVICES := hiker,x9-p910nd-wifi-lite hiker,x9 HIKER
	# Same as p910nd-wifi but use smaller wpad variant for 8M/32M devices.
	DEVICE_PACKAGES := luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer \
		hiker-x9-p910nd-wifi-lite-defaults \
		kmod-mac80211 kmod-rt2800-lib kmod-rt2800-mmio kmod-rt2800-soc \
		kmod-rt2x00-lib kmod-rt2x00-mmio \
		wpad-basic-mbedtls iw iwinfo
endef
TARGET_DEVICES += hiker_x9-p910nd-wifi-lite

define Device/hiker_x9-virtualhere
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 VirtualHere
	DEVICE_DTS := rt5350_hiker_x9-virtualhere
	SUPPORTED_DEVICES := hiker,x9-virtualhere hiker,x9 HIKER
	DEVICE_PACKAGES := luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		virtualhere-usb-server \
		hiker-x9-virtualhere-defaults \
		kmod-usb-core kmod-usb-ohci kmod-usb2
endef
TARGET_DEVICES += hiker_x9-virtualhere

define Device/hiker_x9-virtualhere-wifi
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 VirtualHere WiFi
	DEVICE_DTS := rt5350_hiker_x9-virtualhere-wifi
	SUPPORTED_DEVICES := hiker,x9-virtualhere-wifi hiker,x9 HIKER
	DEVICE_PACKAGES := -wpad-basic-mbedtls luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		virtualhere-usb-server \
		hiker-x9-virtualhere-wifi-defaults \
		kmod-usb-core kmod-usb-ohci kmod-usb2 \
		kmod-mac80211 kmod-rt2800-lib kmod-rt2800-mmio kmod-rt2800-soc \
		kmod-rt2x00-lib kmod-rt2x00-mmio \
		wpad-mbedtls iw iwinfo
endef
TARGET_DEVICES += hiker_x9-virtualhere-wifi

define Device/hiker_x9-both
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print + VirtualHere
	DEVICE_DTS := rt5350_hiker_x9-both
	SUPPORTED_DEVICES := hiker,x9-both hiker,x9 HIKER
	DEVICE_PACKAGES := \
		luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer \
		virtualhere-usb-server \
		hiker-x9-both-defaults \
		-wpad-basic-mbedtls \
		-iw -iwinfo
endef
TARGET_DEVICES += hiker_x9-both

define Device/hiker_x9-both-wifi
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print + VirtualHere WiFi
	DEVICE_DTS := rt5350_hiker_x9-both-wifi
	SUPPORTED_DEVICES := hiker,x9-both-wifi hiker,x9 HIKER
	DEVICE_PACKAGES := -wpad-basic-mbedtls luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		$(HIKER_X9_STRIP) \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer \
		virtualhere-usb-server \
		hiker-x9-both-wifi-defaults \
		kmod-mac80211 kmod-rt2800-lib kmod-rt2800-mmio kmod-rt2800-soc \
		kmod-rt2x00-lib kmod-rt2x00-mmio \
		wpad-mbedtls iw iwinfo
endef
TARGET_DEVICES += hiker_x9-both-wifi
