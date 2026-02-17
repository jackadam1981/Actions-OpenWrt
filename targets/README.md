# targets 目录说明

每个子目录代表一个编译目标（硬件/型号），矩阵编译会遍历所有包含 `.config` 的目标。

## 结构

- **targets/<name>/.config** — 必选，该目标的 OpenWrt 编译配置。
- **targets/<name>/target/** — 可选，覆盖到 OpenWrt 源码的 `target/`（如上游不支持的型号可放 `target/linux/*` 等）。
- **targets/<name>/etc/** — 可选，覆盖到 `package/base-files/files/etc/`（固件内 `/etc` 默认文件）。

## 示例

- 仅用上游支持的设备：`targets/dir-505/.config`、`targets/x86-64/.config`。
- 上游不支持的型号（如 hiker-x9）：`targets/hiker-x9/.config` + `targets/hiker-x9/target/linux/***`，可选 `targets/hiker-x9/etc/***`。构建时会先拷贝 `.config`，再 rsync `target/`、`etc/` 到源码树。

## 添加新目标

1. 新建目录 `targets/<目标名>/`。
2. 放入 `targets/<目标名>/.config`。
3. 如需自定义内核/设备树等，在 `targets/<目标名>/target/` 下按 OpenWrt 源码结构放置（如 `target/linux/mediatek/...`）。
4. 如需该型号默认的 `/etc` 文件，在 `targets/<目标名>/etc/` 下放置，会合并到 `package/base-files/files/etc/`。

---

## printserver 与 openwrt-custom-devices

设计上使用 **printserver** 作为一类 target（`CONFIG_TARGET_printserver`），下面可挂多种设备：例如 **hikerx9**、也可以再写一份 **dir-505** 等。和原来已有的 ramips 设备（如 `targets/dir-505` 用 `CONFIG_TARGET_ath79_...`）并存：前者是传统 target，后者是 printserver target 下的设备。

- **targets/hiker-x9/.config**：`CONFIG_TARGET_printserver=y`、`CONFIG_TARGET_printserver_hikerx9=y`、`CONFIG_TARGET_MULTI_PROFILE=y`。
- 若要在 printserver 下增加 dir-505：在 openwrt-custom-devices 里增加 printserver 的 dir-505 设备定义，在本仓增加 `targets/dir-505-printserver/.config`（或同名目录），选 `CONFIG_TARGET_printserver_dir505` 等对应选项即可。

**仓库** [jackadam1981/openwrt-custom-devices](https://github.com/jackadam1981/openwrt-custom-devices) 以 feed 形式加入，target 由 `feeds install -p targets -f` 安装。

---

## 如何修正 base-files.version / base-files= 报错（printserver + APK）

报错含义：`package/Makefile` 在 APK 安装阶段会执行  
`"base-files=$(shell cat $(STAGING_DIR)/base-files.version)"`，若该文件不存在则得到 `base-files=`，APK 会报「不是合法依赖格式」。

**base-files.version 由谁生成**：在 **package/base-files/Makefile** 里，当 `CONFIG_USE_APK=y` 时，在 **Package/base-files/install** 步骤末尾会执行：  
`echo $(PKG_RELEASE)~$(REVISION) >$(STAGING_DIR)/base-files.version`。  
也就是说：只有 **base-files 被编译并执行了 install** 后，该文件才会出现。

**根本原因**：printserver 目标下当前没有把 base-files 纳入要安装的包，或 build 顺序/多 profile 导致 base-files 未在该 staging 目录下安装，所以 `base-files.version` 未被生成。

**推荐修正方式（任选其一或并用）**：

1. **OpenWrt 主线**  
   在 printserver 目标或对应设备的定义里，把 **base-files** 加入该 target 的默认包（例如 `DEFAULT_PACKAGES` 或 profile 的包列表），保证会执行 `package/base-files` 的 compile + install，从而在 `$(STAGING_DIR)/base-files.version` 生成文件。

2. **openwrt-custom-devices**  
   仓库中已为 printserver hiker-x9 增加默认包 profile，参考 RT5350/ramips 的默认集（与 `include/target.mk` 一致的基础包 + router 类型包 + kmod-leds-gpio、kmod-gpio-button-hotplug）：  
   **target/linux/printserver/profiles/hiker-x9.mk** 中定义了 `Profile/hikerx9` 的 `PACKAGES`（含 base-files、libc、netifd、dnsmasq、firewall4 等）。  
   在 OpenWrt 中需让 printserver 目标 **include 该 profiles 目录**（例如在 printserver 的 Makefile 里通过 `IncludeProfiles` 或 `-include profiles/hiker-x9.mk`），这样选 CONFIG_TARGET_printserver_hikerx9 时才会带上这些默认包，从而生成 base-files.version。

3. **本仓兜底（diy-part2.sh）**  
   若暂时无法改上游，可在本仓的 diy-part2 里对使用 APK 的 printserver 构建**强制选中 base-files**（见下），让 base-files 参与编译和 install，从而生成 `base-files.version`。
