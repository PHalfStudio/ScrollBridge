# Testing

## 已执行

- Debug build（调试构建）：通过。
- Release build（发布构建）：通过。
- Core unit tests（核心单元测试）：151 项通过。
- UI smoke test target build（界面冒烟测试目标构建）：通过，已纳入共享 scheme（方案）。
- UI automation run（界面自动化运行）：2026-06-19 尝试运行 MouseBridgeUITests（界面测试目标），约 149 秒后停在测试启动与日志归集阶段，结果为 TEST INTERRUPTED（测试被中断），未计为通过。
- Codesign verify（签名校验）：通过。
- DMG（磁盘映像）生成与校验：通过。


## 当前验证环境

- macOS（苹果桌面系统）：26.5.1，build（构建号）25F80。
- MacBook Air（苹果笔记本）：Apple M2，arm64（苹果芯片）。
- Release build（发布构建）：已生成 universal binary（通用二进制），包含 arm64（苹果芯片）和 x86_64（英特尔）。

## 命令

```bash
xcodebuild -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeDerivedData build
xcodebuild build-for-testing -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeUnitDerivedData
DYLD_FALLBACK_LIBRARY_PATH=/tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/MacOS $(xcrun -f xctest) /tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/PlugIns/MouseBridgeTests.xctest
xcodebuild build-for-testing -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeUISchemeDerivedData
xcodebuild -project MouseBridge.xcodeproj -scheme MouseBridge -configuration Release -destination 'generic/platform=macOS' -derivedDataPath /tmp/MouseBridgeReleaseDerivedData build
codesign --verify --deep --strict --verbose=2 build/ScrollBridge.app
hdiutil create -volname ScrollBridge -srcfolder build/ScrollBridge.app -format UDZO build/ScrollBridge.dmg
hdiutil verify build/ScrollBridge.dmg
```

## 说明

UI automation（界面自动化）在当前环境无法启用 automation mode（自动化模式）；MouseBridgeUITests 已纳入共享 scheme（方案），本机授权后可直接运行冒烟测试。
