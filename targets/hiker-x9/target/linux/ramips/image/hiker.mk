# Hiker RT5350 Device Profiles

define Device/hiker_hiker-common
	SOC := rt5350
	IMAGE_SIZE := 7872k
	DEVICE_VENDOR := Hiker
endef

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
		-wpad-basic-mbedtls \
		-iw -iwinfo
endef
TARGET_DEVICES += hiker_x9-minimal

define Device/hiker_x9-p910nd
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print
	DEVICE_DTS := rt5350_hiker_x9-p910nd
	SUPPORTED_DEVICES := hiker,x9-print hiker,x9 HIKER
	DEVICE_PACKAGES := luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer
endef
TARGET_DEVICES += hiker_x9-p910nd

define Device/hiker_x9-p910nd-wifi
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 Print WiFi
	DEVICE_DTS := rt5350_hiker_x9-p910nd-wifi
	SUPPORTED_DEVICES := hiker,x9-p910nd-wifi hiker,x9 HIKER
	DEVICE_PACKAGES := -wpad-basic-mbedtls luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
		p910nd luci-app-p910nd luci-i18n-p910nd-zh-cn \
		kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-usb-printer \
		kmod-mac80211 kmod-rt2800-lib kmod-rt2800-mmio kmod-rt2800-soc \
		kmod-rt2x00-lib kmod-rt2x00-mmio \
		wpad-mbedtls iw iwinfo
endef
TARGET_DEVICES += hiker_x9-p910nd-wifi

define Device/hiker_x9-virtualhere
	$(call Device/hiker_hiker-common)
	DEVICE_MODEL := Hiker X9 VirtualHere
	DEVICE_DTS := rt5350_hiker_x9-virtualhere
	SUPPORTED_DEVICES := hiker,x9-virtualhere hiker,x9 HIKER
	DEVICE_PACKAGES := luci-light luci-theme-bootstrap \
		luci-i18n-base-zh-cn \
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
		virtualhere-usb-server \
		hiker-x9-virtualhere-wifi-defaults \
		kmod-usb-core kmod-usb-ohci kmod-usb2 \
		kmod-mac80211 kmod-rt2800-lib kmod-rt2800-mmio kmod-rt2800-soc \
		kmod-rt2x00-lib kmod-rt2x00-mmio \
		wpad-mbedtls iw iwinfo
endef
TARGET_DEVICES += hiker_x9-virtualhere-wifi
