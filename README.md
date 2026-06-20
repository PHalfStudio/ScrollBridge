<p align="center">
  <img src="MouseBridge/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="112" height="112" alt="ScrollBridge App Icon">
</p>

<h1 align="center">ScrollBridge</h1>

<p align="center">
  本地运行的 macOS 菜单栏鼠标工具，让普通鼠标滚轮、平滑滚动和侧键映射更符合个人习惯。
</p>

<div align="center">

[中文](https://github.com/PHalfStudio/ScrollBridge/blob/main/README.md) · [English](https://github.com/PHalfStudio/ScrollBridge/blob/main/README_EN.md)

</div>

---

## 简介

ScrollBridge 是一个原生 macOS 菜单栏 App，面向同时使用普通鼠标、触控板和多键鼠标的用户。它默认只处理物理鼠标滚轮，尽量保留触控板自然滚动体验，并提供侧键映射、平滑滚动、设备诊断和排除 App 等能力。

项目目标是保持本地、透明、可验证：输入事件只在本机处理，不上传输入内容，不保存键入文本，不读取剪贴板。

## 功能特性

- 菜单栏常驻：快速打开设置、权限与诊断、关于页面，支持退出和恢复默认设置。
- 滚轮方向：默认反转物理鼠标垂直滚轮，保留触控板自然滚动。
- 平滑滚动：支持步数、持续时间、曲线、速度倍率、惯性模拟和水平滚动设置。
- 侧键映射：支持 Button 3 到 Button 12，包含手动录制、独立按键拼接录制、预制键盘快捷键和系统动作。
- 系统动作：支持调度中心、当前 App 窗口、左右空间切换、显示桌面等常用 macOS 动作。
- 排除 App：前台 App 命中排除列表时，滚轮和侧键事件保持原样。
- 设备诊断：显示 HID（Human Interface Device，人机接口设备）设备、连接方式、用途、置信度和最近事件。
- 多语言：支持简体中文、English（英文）和跟随系统。
- 开机自启：使用 SMAppService（Service Management App Service，系统登录项服务），默认关闭。

## 安装

请前往 GitHub Releases 下载最新版本：

[https://github.com/PHalfStudio/ScrollBridge/releases/latest](https://github.com/PHalfStudio/ScrollBridge/releases/latest)

使用方式：

1. 下载最新的 ScrollBridge DMG（磁盘映像）文件。
2. 打开 DMG（磁盘映像），将 ScrollBridge 拖入 `/Applications`。
3. 首次启动后按引导授予输入监控和辅助功能权限。
4. 权限变更后，按 macOS 提示重启 App 或重新登录。

## 权限说明

ScrollBridge 需要以下权限：

- 输入监控：读取鼠标滚轮、侧键和录制快捷键所需的键盘事件。
- 辅助功能：用于发送用户配置的滚动和快捷键事件。

隐私原则：

- 只在本机处理输入事件。
- 不上传输入内容。
- 不保存键入文本。
- 不保存录制过程中的字符输入序列。
- 不读取剪贴板。

完整隐私说明见：[PRIVACY.md](https://sites.phalfstudio.cn/scroll-bridge-privacy)。

## 从源码构建

环境要求：

- macOS 26 或更新版本。
- Xcode 26 或更新版本。
- Swift 6。

构建：

```bash
xcodebuild -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeDerivedData build
```

运行核心测试：

```bash
xcodebuild build-for-testing -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeUnitDerivedData
DYLD_FALLBACK_LIBRARY_PATH=/tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/MacOS $(xcrun -f xctest) /tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/PlugIns/MouseBridgeTests.xctest
```

## 已知限制

- Logitech、Razer、SteelSeries 等厂商的专有鼠标按钮可能被厂商驱动拦截，或不以标准 HID（Human Interface Device，人机接口设备）按钮上报。
- 这类按钮无法识别时，可尝试关闭厂商驱动或切换到标准按钮模式后重试。
- 部分 macOS 系统动作没有稳定公开接口，项目会优先使用更接近系统行为的事件路径。

## 卸载

1. 退出菜单栏 App。
2. 删除 `/Applications/ScrollBridge.app`。
3. 在“系统设置 > 隐私与安全性 > 输入监控 / 辅助功能”中移除 ScrollBridge。
4. 如需清理配置，删除 `~/Library/Preferences/cn.phalfstudio.MouseBridge.plist`。

## 许可证

开源许可见：[LICENSES.md](https://sites.phalfstudio.cn/scroll-bridge-license)。

## 致谢与友链

ScrollBridge 参考了 Mac Mouse Fix、Scroll Reverser、Mos、LinearMouse 和 Karabiner-Elements 等项目的公开设计经验。

友链：[linux.do](https://linux.do)

<p>
  <img src="docs/images/linuxdo.png" width="96" height="96" alt="linux.do Logo">
</p>

linux.do 是一个重视长期交流质量的技术社区。社区文化强调：真诚、友善、团结、专业，共建你我引以为荣之社区。
