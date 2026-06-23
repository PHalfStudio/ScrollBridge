<p align="center">
  <img src="MouseBridge/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="112" height="112" alt="MouseBridge App Icon">
</p>

<h1 align="center">MouseBridge</h1>

<p align="center">
  A local macOS menu bar utility for mouse wheel direction, smooth scrolling, and mouse button shortcut mapping.
</p>

<div align="center">

[中文](https://github.com/PHalfStudio/MouseBridge/blob/main/README.md) · [English](https://github.com/PHalfStudio/MouseBridge/blob/main/README_EN.md)

</div>

---

## Introduction

MouseBridge is a native macOS menu bar app for users who work with a regular mouse, a trackpad, or a multi-button mouse. It focuses on physical mouse wheel events by default, preserves the natural scrolling experience of the trackpad as much as possible, and provides mouse button mapping, smooth scrolling, device diagnostics, and app exclusions.

The project is designed to stay local, transparent, and verifiable: input events are processed on the device only. MouseBridge does not upload input content, save typed text, or read clipboard data.

## Features

- Menu bar utility: quickly open settings, permissions and diagnostics, the about page, quit the app, or restore defaults.
- Wheel direction: reverse the vertical wheel direction of a physical mouse while preserving trackpad natural scrolling.
- Smooth scrolling: configure steps, duration, curve, speed multiplier, inertia simulation, and horizontal scrolling.
- Mouse button mapping: supports Button 3 through Button 12, including live recording, independent key composition recording, preset keyboard shortcuts, and system actions.
- System actions: supports Mission Control, App Exposé, switching spaces, Show Desktop, and other common macOS actions.
- App exclusions: keep wheel and button events unchanged when the foreground app matches the exclusion list.
- Device diagnostics: shows HID (Human Interface Device) devices, connection type, usage, confidence, and recent events.
- Localization: supports Simplified Chinese, English, and system language.
- Launch at login: uses SMAppService (Service Management App Service), disabled by default.

## Installation

Download the latest version from GitHub Releases:

[latest](https://github.com/PHalfStudio/MouseBridge/releases/latest)

Usage:

1. Download the latest MouseBridge DMG (disk image) file.
2. Open the DMG (disk image), then drag MouseBridge into `/Applications`.
3. On first launch, grant Input Monitoring and Accessibility permissions as guided.
4. After permission changes, restart the app or sign in again when macOS asks for it.

## Permissions

MouseBridge requires the following permissions:

- Input Monitoring: reads mouse wheel, mouse button, and keyboard events needed for shortcut recording.
- Accessibility: sends configured scrolling and keyboard shortcut events.

Privacy principles:

- Input events are processed locally only.
- Input content is not uploaded.
- Typed text is not saved.
- Character input sequences during recording are not saved.
- Clipboard data is not read.

Full privacy statement: [PRIVACY.md](https://sites.phalfstudio.cn/scroll-bridge-privacy).

## Build from Source

Requirements:

- macOS 26 or later.
- Xcode 26 or later.
- Swift 6.

Build:

```bash
xcodebuild -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeDerivedData build
```

Run core tests:

```bash
xcodebuild build-for-testing -project MouseBridge.xcodeproj -scheme MouseBridge -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MouseBridgeUnitDerivedData
DYLD_FALLBACK_LIBRARY_PATH=/tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/MacOS $(xcrun -f xctest) /tmp/MouseBridgeUnitDerivedData/Build/Products/Debug/MouseBridge.app/Contents/PlugIns/MouseBridgeTests.xctest
```

## Known Limitations

- Proprietary mouse buttons from Logitech, Razer, SteelSeries, and similar vendors may be intercepted by vendor drivers or may not be reported as standard HID (Human Interface Device) buttons.
- When these buttons cannot be detected, try disabling the vendor driver or switching the device to a standard button mode.
- Some macOS system actions do not provide stable public APIs. MouseBridge prioritizes event paths that stay close to native system behavior.

## Uninstall

1. Quit the menu bar app.
2. Delete `/Applications/MouseBridge.app`.
3. Remove MouseBridge from System Settings > Privacy & Security > Input Monitoring / Accessibility.
4. To remove local preferences, delete `~/Library/Preferences/cn.phalfstudio.MouseBridge.plist`.

## License

Open source license: [LICENSES.md](https://sites.phalfstudio.cn/scroll-bridge-license).

## Acknowledgements and Friends

MouseBridge is informed by public design experience from Mac Mouse Fix, Scroll Reverser, Mos, LinearMouse, Karabiner-Elements, and related projects.

<img src="docs/images/linuxdo.png" width="20" height="20" alt="linux.do Logo"> [linux.do](https://linux.do)

Sincerity, kindness, unity, and professionalism, building a community that everyone can be proud of.
