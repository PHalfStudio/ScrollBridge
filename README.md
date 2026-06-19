# ScrollBridge

ScrollBridge 是本地运行的 macOS 菜单栏鼠标工具，用于让普通鼠标滚轮方向接近 Windows 习惯，同时保持触控板自然滚动不变。

## 已实现功能

- 菜单栏常驻：打开设置、权限与诊断、关于、退出；设置开关和恢复默认设置按钮提供 VoiceOver（屏幕朗读）提示。
- 滚动方向：默认只反转物理鼠标垂直滚轮，不处理触控板连续滚动。
- 平滑滚动：支持开关、步数 1 到 20、持续时间、滚动曲线、惯性模拟、速度倍率和水平滚动开关。
- 排除 App：前台 App 命中排除列表时，滚轮和侧键事件保持原样；添加按钮提供 VoiceOver（屏幕朗读）提示。
- 冲突提示：权限与诊断页检测常见鼠标工具，只提示，不关闭其他 App。
- 按键映射：支持 Button 3 到 Button 12 映射为键盘快捷键，默认 Button 4 为 Command+C（Command+C），Button 5 为 Command+V（Command+V）；新增映射会先选择鼠标按钮，选中后自动开启快捷键录制，录制、重录、保存和取消按钮提供 VoiceOver（屏幕朗读）提示；映射列表行会读出按钮、快捷键、作用范围和备注，新增、编辑、删除和使用最近按钮也提供 VoiceOver（屏幕朗读）提示；录制时需在 15 秒内完成，Esc（退出键）取消，Delete（删除键）清空；无效 keyCode（键码）不会进入保存配置。
- 首次启动：先显示欢迎与权限检查流程，完成后才启用事件处理。
- 权限与诊断：显示输入监控、辅助功能、带 VoiceOver（屏幕朗读）说明的授权按钮和操作按钮、登录项、事件监听、当前设备清单、带 VoiceOver（屏幕朗读）提示的诊断行、最近事件、最近错误、错误码、本地化事件回调耗时、事件回调性能统计和非敏感日志。
- 设备页：读取 HID（Human Interface Device，人机接口设备）设备，显示厂商、产品、连接方式、用途、标准 HID、置信度和最近事件，并支持手动标记鼠标、触控板、Magic Mouse（苹果妙控鼠标）、键盘、忽略；刷新按钮、设备行和设备类型选择器提供 VoiceOver（屏幕朗读）提示。
- 多语言：跟随系统、简体中文、English（英文）。
- 关于页：显示真实 AppIcon（应用图标）、版本、构建号、开源许可、隐私说明和参考项目致谢。
- 开机自启：使用 SMAppService（Service Management App Service，系统登录项服务），默认关闭。
- 睡眠唤醒：唤醒后重新检测权限、设备和事件监听。配置读取失败时会备份损坏数据并恢复默认配置。

## 构建与测试

```bash
xcodebuild -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeDerivedData build
xcodebuild build-for-testing -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeUnitDerivedData
DYLD_FALLBACK_LIBRARY_PATH=/tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/MacOS $(xcrun -f xctest) /tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/PlugIns/MouseBridgeTests.xctest
```

交付包位于：

- build/ScrollBridge.app
- build/ScrollBridge.dmg

## 权限说明

ScrollBridge 需要输入监控和辅助功能权限。应用只在本机处理鼠标、滚轮和用户配置的快捷键事件，不上传输入内容，不保存键入文本，不保存录制过程中的字符输入序列，不读取剪贴板。

## 已知限制

- Logitech、Razer、SteelSeries 等厂商的专有鼠标按钮可能被厂商驱动拦截，或不以标准 HID（Human Interface Device，人机接口设备）按钮上报。
- 这类按钮无法识别时，可尝试关闭厂商驱动或切换到标准按钮模式后重试。

## 卸载

1. 退出菜单栏 App。
2. 删除 /Applications/ScrollBridge.app。
3. 在“系统设置 > 隐私与安全性 > 输入监控 / 辅助功能”中移除 ScrollBridge。
4. 如需清理配置，删除 ~/Library/Preferences/cn.phalfstudio.MouseBridge.plist。
