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
