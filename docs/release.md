# Release

## 当前产物

- build/MouseBridge.app
- build/MouseBridge.dmg

当前构建使用 Apple Development（苹果开发证书）签名，应用二进制包含 arm64（苹果芯片）和 x86_64（英特尔）两种架构，可用于本机调试和验证。DMG（磁盘映像）已生成并通过 hdiutil verify（磁盘映像校验）。

当前环境未检测到 Developer ID Application（开发者 ID 应用证书），因此 Notarization（苹果公证）未执行。

## 1.0 发布步骤

1. 使用 Developer ID Application（开发者 ID 应用证书）归档。
2. 使用 notarytool（公证工具）提交公证。
3. 公证成功后 staple（装订）到 App 和 DMG。
4. 再执行 codesign（代码签名）和 spctl（安全评估）校验。
5. 发布 DMG，并同步更新 CHANGELOG.md（变更记录）。
