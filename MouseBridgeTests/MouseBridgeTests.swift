import CoreGraphics
import Foundation
import Testing
@testable import MouseBridge


private final class EventTapStatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [EventTapRuntimeStatus] = []

    func append(_ status: EventTapRuntimeStatus) {
        lock.lock()
        values.append(status)
        lock.unlock()
    }

    var last: EventTapRuntimeStatus? {
        lock.lock()
        let value = values.last
        lock.unlock()
        return value
    }
}

private extension CGEventMask {    func containsEvent(_ type: CGEventType) -> Bool {
        (self & CGEventMask(1 << type.rawValue)) != 0
    }
}

struct MouseBridgeCoreTests {
    private var authorizedSnapshot: RuntimeConfigSnapshot {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        return settings.runtimeSnapshot(
            permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized)
        )
    }

    private var mouseWheelEvent: ScrollEventDescriptor {
        ScrollEventDescriptor(
            deltaX: 0,
            deltaY: -3,
            pointDeltaX: 0,
            pointDeltaY: -36,
            isContinuous: false,
            deviceKind: .mouse,
            isSyntheticFromThisApp: false
        )
    }

    @Test func aboutMetadataUsesBundleDictionaryAndReleaseDefaults() {
        let metadata = AppAboutMetadata(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "45",
            "ScrollBridgeGitCommit": "abc1234",
            "NSHumanReadableCopyright": "© 2026 Example"
        ])
        #expect(metadata.version == "1.2.3")
        #expect(metadata.build == "45")
        #expect(metadata.gitCommit == "abc1234")
        #expect(metadata.copyright == "© 2026 Example")
        #expect(metadata.versionDisplay == "1.2.3 (45)")
        #expect(metadata.licenseFileName == "LICENSES.md")
        #expect(metadata.privacyFileName == "PRIVACY.md")
        #expect(metadata.updateStatusKey == "about.updateUnavailable")
    }

    @Test func aboutMetadataFallsBackWhenBuildValuesAreMissing() {
        let metadata = AppAboutMetadata(infoDictionary: [:])
        #expect(metadata.version == "1.0")
        #expect(metadata.build == "1")
        #expect(metadata.gitCommit == "unknown")
        #expect(metadata.copyright == "© 2026 phalfstudio")
    }

    @Test func aboutPageShowsBuildNumberSeparately() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let aboutPageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("AboutPage.swift")
        let source = try String(contentsOf: aboutPageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "about.build")

        #expect(source.contains(#"infoRow("about.build", metadata.build)"#))
        #expect(source.contains(#"infoRow("about.privacyPolicy", metadata.privacyFileName)"#))
        #expect(values["en"] == "Build")
        #expect(values["zh-Hans"] == "构建号")
    }

    @Test func aboutPageHasLocalizedPrivacyPolicyRow() throws {
        let values = try localizedStringValues(for: "about.privacyPolicy")

        #expect(values["en"] == "Privacy policy")
        #expect(values["zh-Hans"] == "隐私说明")
    }

    @Test func aboutPageListsReferenceProjectAcknowledgements() throws {
        let metadata = AppAboutMetadata(infoDictionary: [:])
        #expect(metadata.referenceProjectNames == [
            "Mac Mouse Fix",
            "Scroll Reverser",
            "Mos",
            "LinearMouse",
            "Karabiner-Elements"
        ])

        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let aboutPageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("AboutPage.swift")
        let source = try String(contentsOf: aboutPageURL, encoding: .utf8)

        #expect(source.contains("metadata.referenceProjectNames"))
        #expect(source.contains(#"ForEach(metadata.referenceProjectNames, id: \.self)"#))
    }

    @Test func aboutPageUsesApplicationIconWithVoiceOverLabel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let aboutPageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("AboutPage.swift")
        let source = try String(contentsOf: aboutPageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "about.appIcon")

        #expect(source.contains("Image(nsImage: NSApp.applicationIconImage)"))
        #expect(source.contains(#".accessibilityLabel(Text("about.appIcon"))"#))
        #expect(source.contains(#"Image(systemName: "computermouse")"#) == false)
        #expect(values["en"] == "ScrollBridge app icon")
        #expect(values["zh-Hans"] == "ScrollBridge 应用图标")
    }

    @Test func settingsAboutPageDoesNotAddToolbarTopPadding() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewsRoot = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
        let aboutSource = try String(contentsOf: viewsRoot.appendingPathComponent("AboutPage.swift"), encoding: .utf8)
        let settingsSource = try String(contentsOf: viewsRoot.appendingPathComponent("SettingsRootView.swift"), encoding: .utf8)

        #expect(aboutSource.contains("init(toolbarSafeAreaTopPadding: CGFloat = 0)"))
        #expect(aboutSource.contains("private let toolbarSafeAreaTopPadding: CGFloat"))
        #expect(aboutSource.contains(#".padding(.top, toolbarSafeAreaTopPadding)"#) == false)
        #expect(settingsSource.contains("AboutPage(toolbarSafeAreaTopPadding: 72)"))
    }

    @Test func appIconAssetSlotsReferenceExistingPNGFiles() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appIconURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("AppIcon.appiconset")
        let contentsURL = appIconURL.appendingPathComponent("Contents.json")
        let data = try Data(contentsOf: contentsURL)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try #require(object["images"] as? [[String: Any]])
        let filenames = images.compactMap { $0["filename"] as? String }

        #expect(filenames.count == images.count)
        #expect(Set(filenames).count == filenames.count)
        #expect(filenames.contains("AppIcon-1024.png"))

        for filename in filenames {
            #expect(FileManager.default.fileExists(atPath: appIconURL.appendingPathComponent(filename).path))
            #expect(filename.hasSuffix(".png"))
        }
    }

    @Test func readmeIncludesRequiredUninstallSteps() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let readmeURL = projectRoot.appendingPathComponent("README.md")
        let readme = try String(contentsOf: readmeURL, encoding: .utf8)

        #expect(readme.contains("退出菜单栏 App"))
        #expect(readme.contains("/Applications/ScrollBridge.app"))
        #expect(readme.contains("系统设置 > 隐私与安全性 > 输入监控 / 辅助功能"))
        #expect(readme.contains("~/Library/Preferences/cn.phalfstudio.MouseBridge.plist"))
    }

    @Test func readmeNamesKnownVendorButtonLimitations() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let readme = try String(contentsOf: projectRoot.appendingPathComponent("README.md"), encoding: .utf8)

        #expect(readme.contains("Logitech"))
        #expect(readme.contains("Razer"))
        #expect(readme.contains("SteelSeries"))
        #expect(readme.contains("厂商驱动"))
    }

    @Test func privacyPolicyStatesShortcutRecordingDoesNotStoreCharacterSequences() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let privacy = try String(contentsOf: projectRoot.appendingPathComponent("PRIVACY.md"), encoding: .utf8)

        #expect(privacy.contains("只保存 keyCode（虚拟键码）、modifier（修饰键）和展示名称"))
        #expect(privacy.contains("不保存录制过程中的字符输入序列"))
    }

    @Test func permissionUsageDescriptionsHaveLocalizedInfoPlistStrings() throws {
        let english = try infoPlistStrings(localeDirectoryName: "en.lproj")
        let chinese = try infoPlistStrings(localeDirectoryName: "zh-Hans.lproj")

        let englishInput = try #require(english["NSInputMonitoringUsageDescription"])
        let englishAccessibility = try #require(english["NSAccessibilityUsageDescription"])
        let chineseInput = try #require(chinese["NSInputMonitoringUsageDescription"])
        let chineseAccessibility = try #require(chinese["NSAccessibilityUsageDescription"])

        #expect(englishInput.contains("locally"))
        #expect(englishInput.contains("does not upload"))
        #expect(englishInput.contains("does not save typed text"))
        #expect(englishInput.contains("does not read the clipboard"))
        #expect(englishAccessibility.contains("does not upload"))
        #expect(englishAccessibility.contains("does not save typed text"))
        #expect(englishAccessibility.contains("does not read the clipboard"))
        #expect(chineseInput.contains("本机"))
        #expect(chineseInput.contains("不会上传"))
        #expect(chineseInput.contains("不会保存键入文本"))
        #expect(chineseInput.contains("不会读取剪贴板"))
        #expect(chineseAccessibility.contains("不会上传"))
        #expect(chineseAccessibility.contains("不会保存键入文本"))
        #expect(chineseAccessibility.contains("不会读取剪贴板"))
    }

    @Test func baseInfoPlistPermissionDescriptionsIncludePrivacyBoundaries() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = projectRoot
            .appendingPathComponent("Config")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let input = try #require(plist["NSInputMonitoringUsageDescription"] as? String)
        let accessibility = try #require(plist["NSAccessibilityUsageDescription"] as? String)

        for value in [input, accessibility] {
            #expect(value.contains("does not upload"))
            #expect(value.contains("does not save typed text"))
            #expect(value.contains("does not read the clipboard"))
        }
    }

    @Test func projectBuildSettingsPermissionDescriptionsIncludePrivacyBoundaries() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectFile = projectRoot
            .appendingPathComponent("MouseBridge.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let source = try String(contentsOf: projectFile, encoding: .utf8)
        let accessibilityKeyCount = source.components(separatedBy: "INFOPLIST_KEY_NSAccessibilityUsageDescription").count - 1
        let inputMonitoringKeyCount = source.components(separatedBy: "INFOPLIST_KEY_NSInputMonitoringUsageDescription").count - 1

        #expect(accessibilityKeyCount == 2)
        #expect(inputMonitoringKeyCount == 2)
        #expect(source.components(separatedBy: "does not upload").count - 1 >= 4)
        #expect(source.components(separatedBy: "does not save typed text").count - 1 >= 4)
        #expect(source.components(separatedBy: "does not read the clipboard").count - 1 >= 4)
    }

    @Test func excludedAppsAddButtonExposesVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "excludedApps.add")
        let hintValues = try localizedStringValues(for: "excludedApps.add.hint")

        #expect(source.contains(#".accessibilityLabel(Text("excludedApps.add"))"#))
        #expect(source.contains(#".accessibilityHint(Text("excludedApps.add.hint"))"#))
        #expect(labelValues["en"] == "Add")
        #expect(labelValues["zh-Hans"] == "添加")
        #expect(hintValues["en"] == "Add the typed bundle identifier to the exclusion list.")
        #expect(hintValues["zh-Hans"] == "将输入的包标识符添加到排除列表。")
    }

    @Test func excludedAppsRowsExposeVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "excludedApps.row.accessibilityLabelFormat")
        let hintValues = try localizedStringValues(for: "excludedApps.row.accessibilityHint")

        #expect(source.contains(#".accessibilityLabel(Text(excludedAppAccessibilityLabel(for: bundleIdentifier)))"#))
        #expect(source.contains(#".accessibilityHint(Text("excludedApps.row.accessibilityHint"))"#))
        #expect(labelValues["en"] == "Excluded app: %@")
        #expect(labelValues["zh-Hans"] == "已排除 App：%@")
        #expect(hintValues["en"] == "Scroll and button mapping stay unchanged while this app is active.")
        #expect(hintValues["zh-Hans"] == "当前台 App 是这一项时，滚动和按键映射保持原样。")
    }

    @Test func excludedAppsRowsExposeDeleteButton() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "excludedApps.delete")
        let hintValues = try localizedStringValues(for: "excludedApps.delete.hint")

        #expect(source.contains(#"Button("excludedApps.delete", role: .destructive)"#))
        #expect(source.contains("appState.removeExcludedBundleIdentifier(bundleIdentifier)"))
        #expect(source.contains(#".accessibilityHint(Text("excludedApps.delete.hint"))"#))
        #expect(labelValues["en"] == "Delete")
        #expect(labelValues["zh-Hans"] == "删除")
        #expect(hintValues["en"] == "Remove this app from the exclusion list.")
        #expect(hintValues["zh-Hans"] == "从排除列表中移除这个 App。")
    }

    @Test func excludedAppsCanBeAddedByChoosingInstalledApplication() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "excludedApps.chooseApp")
        let hintValues = try localizedStringValues(for: "excludedApps.chooseApp.hint")
        let errorValues = try localizedStringValues(for: "excludedApps.chooseApp.invalid")

        #expect(source.contains("NSOpenPanel()"))
        #expect(source.contains("UTType.applicationBundle"))
        #expect(source.contains("Bundle(url: url)?.bundleIdentifier"))
        #expect(source.contains(#"Button("excludedApps.chooseApp")"#))
        #expect(source.contains(#".accessibilityHint(Text("excludedApps.chooseApp.hint"))"#))
        #expect(labelValues["en"] == "Choose App…")
        #expect(labelValues["zh-Hans"] == "选择 App…")
        #expect(hintValues["en"] == "Choose an installed app and add its bundle identifier to the exclusion list.")
        #expect(hintValues["zh-Hans"] == "选择一个已安装 App，并将它的包标识符加入排除列表。")
        #expect(errorValues["en"] == "Could not read this app's bundle identifier.")
        #expect(errorValues["zh-Hans"] == "无法读取这个 App 的包标识符。")
    }

    @Test func smoothScrollSlidersExposeVoiceOverLabelsAndValues() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        #expect(source.contains(#".accessibilityLabel(Text("smooth.steps"))"#))
        #expect(source.contains(#".accessibilityValue(Text("\(appState.settings.smoothSteps)"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("smooth.duration"))"#))
        #expect(source.contains(#".accessibilityValue(Text(smoothDurationValue))"#))
        #expect(source.contains(#".accessibilityLabel(Text("smooth.speedMultiplier"))"#))
        #expect(source.contains(#".accessibilityValue(Text("\(appState.settings.smoothSpeedMultiplier)"))"#))
    }

    @Test func smoothScrollSlidersExposeVoiceOverHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let stepsHint = try localizedStringValues(for: "smooth.steps.hint")
        let durationHint = try localizedStringValues(for: "smooth.duration.hint")
        let speedHint = try localizedStringValues(for: "smooth.speedMultiplier.hint")

        #expect(source.contains(#".accessibilityHint(Text("smooth.steps.hint"))"#))
        #expect(source.contains(#".accessibilityHint(Text("smooth.duration.hint"))"#))
        #expect(source.contains(#".accessibilityHint(Text("smooth.speedMultiplier.hint"))"#))
        #expect(stepsHint["en"] == "Adjust how many synthetic scroll steps are generated for each wheel event.")
        #expect(stepsHint["zh-Hans"] == "调整每次滚轮事件生成的平滑滚动步数。")
        #expect(durationHint["en"] == "Adjust how long each smooth scroll animation lasts.")
        #expect(durationHint["zh-Hans"] == "调整每次平滑滚动动画的持续时间。")
        #expect(speedHint["en"] == "Adjust the strength multiplier applied to smooth scroll output.")
        #expect(speedHint["zh-Hans"] == "调整平滑滚动输出的力度倍数。")
    }

    @Test func settingsToggleRowsExposeVoiceOverHintsFromSubtitles() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sharedViewsURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SharedViews.swift")
        let source = try String(contentsOf: sharedViewsURL, encoding: .utf8)

        #expect(source.contains(#".accessibilityElement(children: .combine)"#))
        #expect(source.contains(#".accessibilityLabel(Text(titleKey))"#))
        #expect(source.contains(#".accessibilityHint(Text(subtitleKey))"#))
    }

    @Test func settingsPickersExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewsRoot = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
        let generalSource = try String(contentsOf: viewsRoot.appendingPathComponent("GeneralPage.swift"), encoding: .utf8)
        let scrollSource = try String(contentsOf: viewsRoot.appendingPathComponent("ScrollDirectionPage.swift"), encoding: .utf8)
        let smoothSource = try String(contentsOf: viewsRoot.appendingPathComponent("SmoothScrollPage.swift"), encoding: .utf8)
        let mappingSource = try String(contentsOf: viewsRoot.appendingPathComponent("ButtonMappingPage.swift"), encoding: .utf8)
        let languageHint = try localizedStringValues(for: "general.language.hint")
        let magicMouseHint = try localizedStringValues(for: "scroll.magicMouse.strategy.hint")
        let curveHint = try localizedStringValues(for: "smooth.curve.hint")
        let mouseButtonHint = try localizedStringValues(for: "mapping.editor.mouseButton.hint")

        #expect(generalSource.contains(#".accessibilityLabel(Text("general.language"))"#))
        #expect(generalSource.contains(#".accessibilityHint(Text("general.language.hint"))"#))
        #expect(scrollSource.contains(#".accessibilityLabel(Text("scroll.magicMouse.strategy"))"#))
        #expect(scrollSource.contains(#".accessibilityHint(Text("scroll.magicMouse.strategy.hint"))"#))
        #expect(smoothSource.contains(#".accessibilityLabel(Text("smooth.curve"))"#))
        #expect(smoothSource.contains(#".accessibilityHint(Text("smooth.curve.hint"))"#))
        #expect(mappingSource.contains(#".accessibilityLabel(Text("mapping.editor.mouseButton"))"#))
        #expect(mappingSource.contains(#".accessibilityHint(Text("mapping.editor.mouseButton.hint"))"#))
        #expect(languageHint["en"] == "Choose the language used by settings and menu text.")
        #expect(languageHint["zh-Hans"] == "选择设置和菜单文字使用的语言。")
        #expect(magicMouseHint["en"] == "Choose how Magic Mouse scrolling is handled.")
        #expect(magicMouseHint["zh-Hans"] == "选择如何处理 Magic Mouse 滚动。")
        #expect(curveHint["en"] == "Choose the timing curve used for smooth scrolling.")
        #expect(curveHint["zh-Hans"] == "选择平滑滚动使用的时间曲线。")
        #expect(mouseButtonHint["en"] == "Choose which mouse button triggers this mapping.")
        #expect(mouseButtonHint["zh-Hans"] == "选择触发这条映射的鼠标按键。")
    }

    @Test func textFieldsExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewsRoot = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
        let smoothSource = try String(contentsOf: viewsRoot.appendingPathComponent("SmoothScrollPage.swift"), encoding: .utf8)
        let mappingSource = try String(contentsOf: viewsRoot.appendingPathComponent("ButtonMappingPage.swift"), encoding: .utf8)
        let excludedHint = try localizedStringValues(for: "excludedApps.placeholder.hint")
        let nameHint = try localizedStringValues(for: "mapping.editor.name.hint")
        let noteHint = try localizedStringValues(for: "mapping.editor.note.hint")

        #expect(smoothSource.contains(#".accessibilityLabel(Text("excludedApps.placeholder"))"#))
        #expect(smoothSource.contains(#".accessibilityHint(Text("excludedApps.placeholder.hint"))"#))
        #expect(mappingSource.contains(#".accessibilityLabel(Text("mapping.editor.name"))"#))
        #expect(mappingSource.contains(#".accessibilityHint(Text("mapping.editor.name.hint"))"#))
        #expect(mappingSource.contains(#".accessibilityLabel(Text("mapping.editor.note"))"#))
        #expect(mappingSource.contains(#".accessibilityHint(Text("mapping.editor.note.hint"))"#))
        #expect(excludedHint["en"] == "Enter a bundle identifier such as com.example.app.")
        #expect(excludedHint["zh-Hans"] == "输入类似 com.example.app 的包标识符。")
        #expect(nameHint["en"] == "Optionally enter a display name for this mapping.")
        #expect(nameHint["zh-Hans"] == "可选填写这条映射的显示名称。")
        #expect(noteHint["en"] == "Optionally enter a note for this mapping.")
        #expect(noteHint["zh-Hans"] == "可选填写这条映射的备注。")
    }

    @Test func restoreDefaultsButtonExposesVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("GeneralPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "general.restoreDefaults")
        let hintValues = try localizedStringValues(for: "general.restoreDefaults.hint")

        #expect(source.contains(#".accessibilityLabel(Text("general.restoreDefaults"))"#))
        #expect(source.contains(#".accessibilityHint(Text("general.restoreDefaults.hint"))"#))
        #expect(labelValues["en"] == "Restore Defaults")
        #expect(labelValues["zh-Hans"] == "恢复默认设置")
        #expect(hintValues["en"] == "Reset ScrollBridge settings to their default values.")
        #expect(hintValues["zh-Hans"] == "将 ScrollBridge 设置恢复为默认值。")
    }

    @Test func smoothScrollDurationValueUsesLocalizedFormat() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SmoothScrollPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "smooth.duration.valueFormat")

        #expect(source.contains(#"Text(smoothDurationValue)"#))
        #expect(source.contains(#".accessibilityValue(Text(smoothDurationValue))"#))
        #expect(source.contains(#""\(appState.settings.smoothDurationMilliseconds) ms""#) == false)
        #expect(values["en"] == "%d ms")
        #expect(values["zh-Hans"] == "%d 毫秒")
    }

    @Test func diagnosticsCallbackDurationUsesLocalizedFormat() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("PermissionsDiagnosticsPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "diagnostics.callbackMillisecondsFormat")

        #expect(source.contains(#"localizedCallbackDuration(appState.eventTapPerformance.averageCallbackMilliseconds)"#))
        #expect(source.contains(#"localizedCallbackDuration(appState.eventTapPerformance.p95CallbackMilliseconds)"#))
        #expect(source.contains(#"%.3f ms"#) == false)
        #expect(values["en"] == "%.3f ms")
        #expect(values["zh-Hans"] == "%.3f 毫秒")
    }

    @Test func buttonMappingListActionButtonsExposeVoiceOverHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let addHint = try localizedStringValues(for: "mapping.add.hint")
        let editHint = try localizedStringValues(for: "mapping.edit.hint")
        let deleteHint = try localizedStringValues(for: "mapping.delete.hint")
        let useLastHint = try localizedStringValues(for: "mapping.useLastButton.hint")

        #expect(source.contains(#".accessibilityLabel(Text("mapping.add"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.add.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("mapping.edit"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.edit.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("mapping.delete"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.delete.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text(String(format: NSLocalizedString("mapping.useLastButton", comment: ""), last)))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.useLastButton.hint"))"#))

        #expect(addHint["en"] == "Create a new mouse button mapping.")
        #expect(addHint["zh-Hans"] == "新建一个鼠标按键映射。")
        #expect(editHint["en"] == "Open this mapping for editing.")
        #expect(editHint["zh-Hans"] == "打开这个映射进行编辑。")
        #expect(deleteHint["en"] == "Delete this button mapping.")
        #expect(deleteHint["zh-Hans"] == "删除这个按键映射。")
        #expect(useLastHint["en"] == "Use the most recently detected mouse button for this mapping.")
        #expect(useLastHint["zh-Hans"] == "将最近检测到的鼠标按键用于这个映射。")
    }

    @Test func buttonMappingListUsesRoundedContainer() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        #expect(source.contains(".listStyle(.plain)"))
        #expect(source.contains(".scrollContentBackground(.hidden)"))
        #expect(source.contains(".clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))"))
        #expect(source.contains("RoundedRectangle(cornerRadius: 16, style: .continuous)"))
    }

    @Test func buttonMappingTogglesExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let pageLabel = try localizedStringValues(for: "mapping.enabled")
        let pageHint = try localizedStringValues(for: "mapping.enabled.hint")
        let editorLabel = try localizedStringValues(for: "mapping.editor.enabled")
        let editorHint = try localizedStringValues(for: "mapping.editor.enabled.hint")

        #expect(source.contains(#".accessibilityLabel(Text("mapping.enabled"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.enabled.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("mapping.editor.enabled"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.editor.enabled.hint"))"#))
        #expect(pageLabel["en"] == "Enable mouse button mapping")
        #expect(pageLabel["zh-Hans"] == "启用鼠标按键映射")
        #expect(pageHint["en"] == "Turn all mouse button mappings on or off.")
        #expect(pageHint["zh-Hans"] == "开启或关闭全部鼠标按键映射。")
        #expect(editorLabel["en"] == "Enabled")
        #expect(editorLabel["zh-Hans"] == "启用")
        #expect(editorHint["en"] == "Turn this individual mapping on or off.")
        #expect(editorHint["zh-Hans"] == "开启或关闭当前这条按键映射。")
    }

    @Test func buttonMappingEditorActionButtonsExposeVoiceOverHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let recordHint = try localizedStringValues(for: "mapping.editor.mouseButton.record.hint")
        let rerecordHint = try localizedStringValues(for: "mapping.editor.rerecord.hint")
        let cancelHint = try localizedStringValues(for: "action.cancel.hint")
        let saveHint = try localizedStringValues(for: "action.save.hint")

        #expect(source.contains(#".accessibilityLabel(Text("mapping.editor.mouseButton.record"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.editor.mouseButton.record.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("mapping.editor.rerecord"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.editor.rerecord.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("action.cancel"))"#))
        #expect(source.contains(#".accessibilityHint(Text("action.cancel.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("action.save"))"#))
        #expect(source.contains(#".accessibilityHint(Text("action.save.hint"))"#))

        #expect(recordHint["en"] == "Start listening for the next supported mouse button press.")
        #expect(recordHint["zh-Hans"] == "开始监听下一次可支持的鼠标按键。")
        #expect(rerecordHint["en"] == "Restart shortcut recording for the selected mouse button.")
        #expect(rerecordHint["zh-Hans"] == "为选中的鼠标按键重新录制快捷键。")
        #expect(cancelHint["en"] == "Close the editor without saving changes.")
        #expect(cancelHint["zh-Hans"] == "关闭编辑器且不保存更改。")
        #expect(saveHint["en"] == "Save this button mapping and close the editor.")
        #expect(saveHint["zh-Hans"] == "保存这个按键映射并关闭编辑器。")
    }

    @Test func buttonMappingShortcutRecorderExposesVoiceOverHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "mapping.editor.shortcut.captureHint")

        #expect(source.contains(#".accessibilityLabel(Text("mapping.editor.shortcut.capture"))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.editor.shortcut.captureHint"))"#))
        #expect(values["en"] == "Press the target keyboard shortcut. Esc cancels and Delete clears.")
        #expect(values["zh-Hans"] == "按下目标键盘快捷键。Esc 取消，Delete 清空。")
    }

    @Test func defaultSettingsMatchProductBehavior() {
        let settings = AppSettings.defaults
        #expect(settings.masterEnabled)
        #expect(settings.reverseMouseWheelEnabled)
        #expect(settings.reverseVertical)
        #expect(settings.preserveTrackpadDirection)
        #expect(settings.physicalWheelOnly)
        #expect(settings.magicMouseScrollStrategy == .preserve)
        #expect(settings.smoothSteps == 8)
        #expect(settings.smoothDurationMilliseconds == 120)
        #expect(settings.smoothCurve == .easeOut)
        #expect(settings.smoothInertiaEnabled == false)
        #expect(settings.launchAtLogin == false)
        #expect(settings.menuBarVisible)
        #expect(settings.schemaVersion == 1)
        #expect(settings.excludedBundleIdentifiers.isEmpty)
    }

    @Test func generalMenuBarVisibilitySettingHasLocalizedCopy() throws {
        let values = try localizedStringValues(for: "general.menuBarVisible")
        let descriptionValues = try localizedStringValues(for: "general.menuBarVisible.desc")

        #expect(values["en"] == "Show in menu bar")
        #expect(values["zh-Hans"] == "在菜单栏显示")
        #expect(descriptionValues["en"] == "Keep the ScrollBridge menu available from the menu bar.")
        #expect(descriptionValues["zh-Hans"] == "保持可以从菜单栏打开 ScrollBridge。")
    }

    @Test func settingsSidebarRowsExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SettingsRootView.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let hints: [(String, String, String)] = [
            ("page.general.hint", "Open general settings.", "打开通用设置。"),
            ("page.scrollDirection.hint", "Open mouse wheel direction settings.", "打开鼠标滚轮方向设置。"),
            ("page.smoothScroll.hint", "Open smooth scrolling settings.", "打开平滑滚动设置。"),
            ("page.buttonMapping.hint", "Open mouse button mapping settings.", "打开鼠标按键映射设置。"),
            ("page.devices.hint", "Open device recognition and classification settings.", "打开设备识别与分类设置。"),
            ("page.permissions.hint", "Open permissions and diagnostics.", "打开权限与诊断。"),
            ("page.about.hint", "Open app version, privacy, and license information.", "打开 App 版本、隐私和许可信息。")
        ]

        #expect(source.contains(#".accessibilityLabel(Text(page.titleKey))"#))
        #expect(source.contains(#".accessibilityHint(Text(page.accessibilityHintKey))"#))
        for (key, english, chinese) in hints {
            #expect(source.contains(key))
            let values = try localizedStringValues(for: key)
            #expect(values["en"] == english)
            #expect(values["zh-Hans"] == chinese)
        }
    }

    @Test func menuBarControlsExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("MenuBarContentView.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let reverseHint = try localizedStringValues(for: "menu.reverseMouseWheel.hint")
        let smoothHint = try localizedStringValues(for: "menu.smoothScrolling.hint")
        let mappingHint = try localizedStringValues(for: "menu.buttonMapping.hint")
        let permissionHint = try localizedStringValues(for: "menu.openPermissionGuide.hint")
        let settingsHint = try localizedStringValues(for: "menu.openSettings.hint")
        let diagnosticsHint = try localizedStringValues(for: "menu.permissionsDiagnostics.hint")
        let aboutHint = try localizedStringValues(for: "menu.about.hint")
        let quitHint = try localizedStringValues(for: "menu.quit.hint")

        for key in [
            "menu.reverseMouseWheel",
            "menu.smoothScrolling",
            "menu.buttonMapping",
            "menu.openPermissionGuide",
            "menu.openSettings",
            "menu.permissionsDiagnostics",
            "menu.about",
            "menu.quit"
        ] {
            #expect(source.contains(#".accessibilityLabel(Text("\#(key)"))"#))
        }
        for key in [
            "menu.reverseMouseWheel.hint",
            "menu.smoothScrolling.hint",
            "menu.buttonMapping.hint",
            "menu.openPermissionGuide.hint",
            "menu.openSettings.hint",
            "menu.permissionsDiagnostics.hint",
            "menu.about.hint",
            "menu.quit.hint"
        ] {
            #expect(source.contains(#".accessibilityHint(Text("\#(key)"))"#))
        }
        #expect(reverseHint["en"] == "Quickly turn physical mouse wheel reversal on or off.")
        #expect(reverseHint["zh-Hans"] == "快速开启或关闭物理鼠标滚轮反转。")
        #expect(smoothHint["en"] == "Quickly turn smooth scrolling on or off.")
        #expect(smoothHint["zh-Hans"] == "快速开启或关闭平滑滚动。")
        #expect(mappingHint["en"] == "Quickly turn mouse button mappings on or off.")
        #expect(mappingHint["zh-Hans"] == "快速开启或关闭鼠标按键映射。")
        #expect(permissionHint["en"] == "Open settings to the permissions and diagnostics page.")
        #expect(permissionHint["zh-Hans"] == "打开设置中的权限与诊断页面。")
        #expect(settingsHint["en"] == "Open the full ScrollBridge settings window.")
        #expect(settingsHint["zh-Hans"] == "打开完整的 ScrollBridge 设置窗口。")
        #expect(diagnosticsHint["en"] == "Open permissions, device, and event listener diagnostics.")
        #expect(diagnosticsHint["zh-Hans"] == "打开权限、设备和事件监听诊断。")
        #expect(aboutHint["en"] == "Open version, privacy, and license information.")
        #expect(aboutHint["zh-Hans"] == "打开版本、隐私和许可信息。")
        #expect(quitHint["en"] == "Stop ScrollBridge and restore normal system input.")
        #expect(quitHint["zh-Hans"] == "退出 ScrollBridge 并恢复系统默认输入。")
    }

    @Test func statusBarIconUsesAppKitStatusItemForMouseClicks() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: projectRoot
                .appendingPathComponent("MouseBridge")
                .appendingPathComponent("App")
                .appendingPathComponent("MouseBridgeApp.swift"),
            encoding: .utf8
        )
        let statusItemURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("App")
            .appendingPathComponent("StatusItemController.swift")
        let statusItemSource = (try? String(contentsOf: statusItemURL, encoding: .utf8)) ?? ""

        #expect(appSource.contains("StatusItemController(appState: appState)"))
        #expect(appSource.contains("MenuBarExtra(") == false)
        #expect(statusItemSource.contains("NSStatusBar.system.statusItem"))
        #expect(statusItemSource.contains("button.sendAction(on: [.leftMouseUp, .rightMouseUp])"))
        #expect(statusItemSource.contains("statusItem.menu = makeMenu()"))
        #expect(statusItemSource.contains("button.performClick(nil)"))
        #expect(statusItemSource.contains("statusItem.menu = nil"))
    }

    @Test func menuBarExtraVisibilityKeepsOnboardingReachable() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = false
        settings.menuBarVisible = false

        #expect(settings.shouldShowMenuBarExtra)

        settings.hasCompletedOnboarding = true
        #expect(settings.shouldShowMenuBarExtra == false)

        settings.menuBarVisible = true
        #expect(settings.shouldShowMenuBarExtra)
    }

    @Test func hiddenMenuBarOpensSettingsAtLaunchForRecovery() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.menuBarVisible = false
        settings.showSettingsAtLaunch = false

        #expect(settings.shouldOpenSettingsWindowAtLaunch)

        settings.menuBarVisible = true
        #expect(settings.shouldOpenSettingsWindowAtLaunch == false)

        settings.showSettingsAtLaunch = true
        #expect(settings.shouldOpenSettingsWindowAtLaunch)
    }

    @Test func hiddenMenuBarInsertsTemporaryEntryUntilRecoveryWindowIsRequested() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.menuBarVisible = false
        settings.showSettingsAtLaunch = false

        #expect(MenuBarInsertionPolicy.shouldInsert(settings: settings, hasRequestedInitialSettingsWindow: false))
        #expect(MenuBarInsertionPolicy.shouldInsert(settings: settings, hasRequestedInitialSettingsWindow: true) == false)

        settings.menuBarVisible = true
        #expect(MenuBarInsertionPolicy.shouldInsert(settings: settings, hasRequestedInitialSettingsWindow: true))
    }

    @Test func defaultButtonMappingsDoNotStoreLocalizedNoteText() {
        let settings = AppSettings.defaults

        #expect(settings.buttonMappings.map(\.mouseButtonNumber) == [4, 5])
        #expect(settings.buttonMappings.allSatisfy { $0.note.isEmpty })
        #expect(settings.buttonMappings.map(\.shortcut.displayName) == ["⌘C", "⌘V"])
    }

    @Test func onboardingIsRequiredBeforeEventProcessing() {
        let snapshot = AppSettings.defaults.runtimeSnapshot(
            permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized)
        )
        #expect(snapshot.shouldHandleEvents == false)
    }

    @Test func completedOnboardingAllowsAuthorizedEventProcessing() {
        #expect(authorizedSnapshot.shouldHandleEvents)
    }

    @Test func missingInputMonitoringDisablesProcessing() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        let snapshot = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .denied, accessibility: .authorized))
        #expect(snapshot.shouldHandleEvents == false)
    }

    @Test func missingAccessibilityDisablesProcessing() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        let snapshot = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .denied))
        #expect(snapshot.shouldHandleEvents == false)
    }

    @Test func masterSwitchDisablesProcessing() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.masterEnabled = false
        let snapshot = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        #expect(snapshot.shouldHandleEvents == false)
    }

    @Test func featureAvailabilityNoticeExplainsWhyFeaturesWillNotApply() {
        var settings = AppSettings.defaults
        let permissions = PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized)

        #expect(FeatureAvailabilityNotice.messageKey(settings: settings, permissions: permissions) == "feature.notice.setupRequired")

        settings.hasCompletedOnboarding = true
        #expect(FeatureAvailabilityNotice.messageKey(settings: settings, permissions: PermissionSummary(inputMonitoring: .denied, accessibility: .authorized)) == "feature.notice.missingPermissions")

        settings.masterEnabled = false
        #expect(FeatureAvailabilityNotice.messageKey(settings: settings, permissions: permissions) == "feature.notice.paused")

        settings.masterEnabled = true
        #expect(FeatureAvailabilityNotice.messageKey(settings: settings, permissions: permissions) == nil)
    }

    @Test func physicalMouseWheelIsReversedVertically() {
        let result = ScrollDirectionEngine().transform(mouseWheelEvent, config: authorizedSnapshot)
        #expect(result.shouldHandle)
        #expect(result.deltaY == 3)
        #expect(result.pointDeltaY == 36)
    }

    @Test func horizontalReverseOnlyChangesHorizontalAxis() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.reverseVertical = false
        settings.reverseHorizontal = true
        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        let event = ScrollEventDescriptor(deltaX: 4, deltaY: 7, pointDeltaX: 40, pointDeltaY: 70, isContinuous: false, deviceKind: .mouse, isSyntheticFromThisApp: false)
        let result = ScrollDirectionEngine().transform(event, config: config)
        #expect(result.deltaX == -4)
        #expect(result.deltaY == 7)
        #expect(result.pointDeltaX == -40)
        #expect(result.pointDeltaY == 70)
    }

    @Test func trackpadScrollIsNotReversed() {
        let event = ScrollEventDescriptor(deltaX: 0, deltaY: -3, pointDeltaX: 0, pointDeltaY: -36, isContinuous: true, deviceKind: .trackpad, isSyntheticFromThisApp: false)
        let result = ScrollDirectionEngine().transform(event, config: authorizedSnapshot)
        #expect(result.shouldHandle == false)
        #expect(result.deltaY == -3)
    }

    @Test func continuousMouseLikeScrollIsIgnoredWhenPhysicalOnly() {
        let event = ScrollEventDescriptor(deltaX: 0, deltaY: -3, pointDeltaX: 0, pointDeltaY: -36, isContinuous: true, deviceKind: .mouse, isSyntheticFromThisApp: false)
        let result = ScrollDirectionEngine().transform(event, config: authorizedSnapshot)
        #expect(result.shouldHandle == false)
    }

    @Test func lowConfidenceMouseCandidateIsNotReversedByDefault() {
        let event = ScrollEventDescriptor(
            deltaX: 0,
            deltaY: -3,
            pointDeltaX: 0,
            pointDeltaY: -36,
            isContinuous: false,
            deviceKind: .mouse,
            classificationConfidence: 0.4,
            isSyntheticFromThisApp: false
        )
        let result = ScrollDirectionEngine().transform(event, config: authorizedSnapshot)
        #expect(result.shouldHandle == false)
        #expect(result.deltaY == -3)
    }

    @Test func syntheticEventsAreIgnored() {
        let event = ScrollEventDescriptor(deltaX: 0, deltaY: -1, pointDeltaX: 0, pointDeltaY: -12, isContinuous: false, deviceKind: .mouse, isSyntheticFromThisApp: true)
        let result = ScrollDirectionEngine().transform(event, config: authorizedSnapshot)
        #expect(result.shouldHandle == false)
        #expect(result.deltaY == -1)
    }

    @Test func eventTapScrollPipelinePassesSyntheticCGEvents() throws {
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: -12,
            wheel2: 0,
            wheel3: 0
        ))
        event.setIntegerValueField(.eventSourceUserData, value: EventTapService.syntheticMarker)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -12)

        let decision = EventTapScrollPipeline(syntheticMarker: EventTapService.syntheticMarker)
            .decision(for: event, config: authorizedSnapshot)

        #expect(decision == .passOriginal)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -1)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -12)
    }

    @Test func eventTapScrollPipelineDoesNotSwallowHorizontalWheelWhenHorizontalSmoothingIsDisabled() throws {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.reverseVertical = false
        settings.reverseHorizontal = true
        settings.smoothScrollingEnabled = true
        settings.smoothSteps = 8
        settings.smoothHorizontalEnabled = false
        let config = settings.runtimeSnapshot(
            permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized)
        )
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 24,
            wheel3: 0
        ))
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 24)

        let decision = EventTapScrollPipeline(syntheticMarker: EventTapService.syntheticMarker)
            .decision(for: event, config: config)

        #expect(decision == .replace(
            ScrollTransformResult(
                shouldHandle: true,
                deltaX: -2,
                deltaY: 0,
                pointDeltaX: -24,
                pointDeltaY: 0
            )
        ))
    }

    @Test func eventTapScrollPipelinePreservesHorizontalDeltaWhileSmoothingVerticalOnly() throws {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.reverseVertical = true
        settings.reverseHorizontal = true
        settings.smoothScrollingEnabled = true
        settings.smoothSteps = 8
        settings.smoothHorizontalEnabled = false
        let config = settings.runtimeSnapshot(
            permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized)
        )
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: -36,
            wheel2: 24,
            wheel3: 0
        ))
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -3)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -36)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 24)

        let decision = EventTapScrollPipeline(syntheticMarker: EventTapService.syntheticMarker)
            .decision(for: event, config: config)

        #expect(decision == .replaceAndSmooth(
            replacement: ScrollTransformResult(
                shouldHandle: true,
                deltaX: -2,
                deltaY: 0,
                pointDeltaX: -24,
                pointDeltaY: 0
            ),
            smooth: SmoothScrollRequest(
                deltaX: 0,
                deltaY: 36,
                location: .zero
            )
        ))
    }

    @Test func disabledReverseFeaturePassesOriginalEvent() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.reverseMouseWheelEnabled = false
        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        let result = ScrollDirectionEngine().transform(mouseWheelEvent, config: config)
        #expect(result.shouldHandle == false)
        #expect(result.deltaY == -3)
    }

    @Test func magicMouseDefaultStrategyPreservesDirection() {
        var event = mouseWheelEvent
        event.deviceKind = .magicMouse
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true

        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        let result = ScrollDirectionEngine().transform(event, config: config)

        #expect(result.shouldHandle == false)
        #expect(result.deltaY == -3)
    }

    @Test func magicMouseCanOptIntoMouseWheelReversal() {
        var event = mouseWheelEvent
        event.deviceKind = .magicMouse
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.magicMouseScrollStrategy = .reverseLikeMouse

        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        let result = ScrollDirectionEngine().transform(event, config: config)

        #expect(result.shouldHandle)
        #expect(result.deltaY == 3)
    }

    @Test func smoothPlannerPreservesTotalDelta() {
        let steps = SmoothScrollPlanner().split(deltaX: 0, deltaY: 37, steps: 8, speedMultiplier: 1)
        #expect(steps.reduce(Int32(0)) { $0 + $1.y } == 37)
        #expect(steps.count <= 8)
    }

    @Test func smoothPlannerClampsStepCount() {
        let steps = SmoothScrollPlanner().split(deltaX: 0, deltaY: 10, steps: 80, speedMultiplier: 1)
        #expect(steps.count <= 20)
        #expect(steps.reduce(Int32(0)) { $0 + $1.y } == 10)
    }

    @Test func smoothPlannerAppliesSpeedMultiplier() {
        let steps = SmoothScrollPlanner().split(deltaX: 0, deltaY: 10, steps: 4, speedMultiplier: 1.5)
        #expect(steps.reduce(Int32(0)) { $0 + $1.y } == 15)
    }

    @Test func smoothPlannerAppliesConfiguredCurve() {
        let linear = SmoothScrollPlanner().split(deltaX: 0, deltaY: 80, steps: 4, speedMultiplier: 1, curve: .linear)
        let easeOut = SmoothScrollPlanner().split(deltaX: 0, deltaY: 80, steps: 4, speedMultiplier: 1, curve: .easeOut)
        #expect(linear.map(\.y) == [20, 20, 20, 20])
        #expect(easeOut.map(\.y) == [35, 25, 15, 5])
        #expect(easeOut.reduce(Int32(0)) { $0 + $1.y } == 80)
    }

    @Test func smoothPlannerAddsInertiaTailWhenEnabled() {
        let steps = SmoothScrollPlanner().split(deltaX: 0, deltaY: 80, steps: 4, speedMultiplier: 1, curve: .linear, inertiaEnabled: true)
        #expect(steps.map(\.y) == [20, 20, 20, 20, 10, 5])
    }

    @Test func settingsNormalizeClampsSmoothValues() {
        var settings = AppSettings.defaults
        settings.smoothSteps = 100
        settings.smoothDurationMilliseconds = -1
        settings.smoothSpeedMultiplier = 99
        settings.normalize()
        #expect(settings.smoothSteps == 20)
        #expect(settings.smoothDurationMilliseconds == 40)
        #expect(settings.smoothSpeedMultiplier == 5.0)
    }

    @Test func runtimeSnapshotCarriesSmoothDuration() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.smoothDurationMilliseconds = 180
        settings.smoothCurve = .linear
        settings.smoothInertiaEnabled = true
        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        #expect(config.smoothDurationMilliseconds == 180)
        #expect(config.smoothCurve == .linear)
        #expect(config.smoothInertiaEnabled)
    }

    @Test func smoothFrameIntervalUsesDurationAndStepCount() {
        #expect(SmoothScrollPlanner().frameInterval(durationMilliseconds: 120, steps: 8) == 0.015)
        #expect(SmoothScrollPlanner().frameInterval(durationMilliseconds: 40, steps: 1) == 0)
    }

    @Test func smoothBackpressureMergesOverflowingQueue() {
        let steps = (0..<201).map { index in
            SmoothStep(
                x: 1,
                y: -2,
                location: CGPoint(x: index, y: index),
                interval: 0.01
            )
        }
        var buffer = SmoothScrollBackpressureBuffer(maxPendingSteps: 200)
        buffer.append(steps, fallbackLocation: .zero)

        #expect(buffer.pendingSteps.count == 1)
        #expect(buffer.pendingSteps[0].x == 201)
        #expect(buffer.pendingSteps[0].y == -402)
        #expect(buffer.pendingSteps[0].location == CGPoint(x: 200, y: 200))
        #expect(buffer.pendingSteps[0].interval == 0.01)
    }

    @Test func excludedBundleIdentifiersAreNormalizedAndApplied() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.excludedBundleIdentifiers = [" com.apple.Safari ", "", "com.apple.Safari"]
        settings.normalize()
        #expect(settings.excludedBundleIdentifiers == ["com.apple.Safari"])
        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        #expect(config.shouldHandleEvents(for: "com.apple.Safari") == false)
        #expect(config.shouldHandleEvents(for: "com.apple.finder"))
        #expect(config.shouldHandleEvents(for: nil))
    }

    @Test func duplicateMouseButtonMappingIsRejected() {
        let shortcut = KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        let existing = ButtonMapping(mouseButtonNumber: 4, shortcut: shortcut)
        let duplicate = ButtonMapping(mouseButtonNumber: 4, shortcut: shortcut)
        #expect(ButtonMappingEngine().canInsert(duplicate, into: [existing]) == false)
    }

    @Test func editingExistingMouseButtonMappingIsAllowed() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let copy = KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        let paste = KeyboardShortcutDefinition(keyCode: 9, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        let existing = ButtonMapping(id: id, mouseButtonNumber: 4, shortcut: copy)
        let edited = ButtonMapping(id: id, mouseButtonNumber: 4, shortcut: paste, note: "Updated")

        #expect(ButtonMappingEngine().canInsert(edited, into: [existing]))
    }

    @Test func duplicateMouseButtonMappingHasConflictWarningKey() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000124")!
        let copy = KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        let paste = KeyboardShortcutDefinition(keyCode: 9, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        let existing = ButtonMapping(id: id, mouseButtonNumber: 4, shortcut: copy)
        let duplicate = ButtonMapping(mouseButtonNumber: 4, shortcut: paste)
        let edited = ButtonMapping(id: id, mouseButtonNumber: 4, shortcut: paste)
        let newButton = ButtonMapping(mouseButtonNumber: 5, shortcut: paste)

        #expect(ButtonMappingConflictWarning.messageKey(for: duplicate, in: [existing]) == "mapping.duplicateMouseButton")
        #expect(ButtonMappingConflictWarning.messageKey(for: edited, in: [existing]) == nil)
        #expect(ButtonMappingConflictWarning.messageKey(for: newButton, in: [existing]) == nil)
    }

    @Test func primaryMouseButtonsCannotBeMapped() {
        let shortcut = KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        #expect(ButtonMappingEngine().canInsert(ButtonMapping(mouseButtonNumber: 1, shortcut: shortcut), into: []) == false)
        #expect(ButtonMappingEngine().canInsert(ButtonMapping(mouseButtonNumber: 2, shortcut: shortcut), into: []) == false)
        #expect(ButtonMappingEngine().canInsert(ButtonMapping(mouseButtonNumber: 3, shortcut: shortcut), into: []))
    }

    @Test func middleMouseButtonMappingHasRiskWarningCopy() throws {
        #expect(ButtonMappingRiskWarning.messageKey(for: 3) == "mapping.editor.middleButtonRisk")
        #expect(ButtonMappingRiskWarning.messageKey(for: 4) == nil)

        let values = try localizedStringValues(for: "mapping.editor.middleButtonRisk")
        #expect(values["en"] == "Middle-click may be used by some apps for tab or paste actions. Keep another way to undo the mapping.")
        #expect(values["zh-Hans"] == "中键可能被部分 App 用于标签页或粘贴操作，请保留其他方式撤销映射。")
    }

    @Test func newButtonMappingEditorRequiresMouseButtonAndShortcutBeforeSaving() {
        let emptyDraft = ButtonMappingEditorDraft.newMapping
        let capturedButtonOnly = ButtonMappingEditorDraft(mouseButtonNumber: 4, shortcut: nil)
        let capturedShortcutOnly = ButtonMappingEditorDraft(
            mouseButtonNumber: 0,
            shortcut: KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        )
        let completeDraft = ButtonMappingEditorDraft(
            mouseButtonNumber: 4,
            shortcut: KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        )

        #expect(emptyDraft.mouseButtonNumber == 0)
        #expect(emptyDraft.shortcut == nil)
        #expect(emptyDraft.canSave(conflictMessageKey: nil) == false)
        #expect(capturedButtonOnly.canSave(conflictMessageKey: nil) == false)
        #expect(capturedShortcutOnly.canSave(conflictMessageKey: nil) == false)
        #expect(completeDraft.canSave(conflictMessageKey: nil))
        #expect(completeDraft.canSave(conflictMessageKey: "mapping.duplicateMouseButton") == false)
    }

    @Test func newButtonMappingEditorDelaysShortcutRecordingUntilMouseButtonIsSelected() throws {
        #expect(ButtonMappingEditorDraft.newMapping.canRecordShortcut == false)
        #expect(ButtonMappingEditorDraft(mouseButtonNumber: 2, shortcut: nil).canRecordShortcut == false)
        #expect(ButtonMappingEditorDraft(mouseButtonNumber: 4, shortcut: nil).canRecordShortcut)

        let values = try localizedStringValues(for: "mapping.editor.shortcut.waitForMouseButton")
        #expect(values["en"] == "Choose a mouse button before recording a shortcut.")
        #expect(values["zh-Hans"] == "请先选择鼠标按钮，再录制快捷键。")
    }

    @Test func newButtonMappingEditorStartsShortcutRecordingAfterMouseButtonSelection() throws {
        #expect(ButtonMappingEditorDraft.newMapping.shouldRestartShortcutRecording(afterChangingMouseButtonTo: 4))
        #expect(ButtonMappingEditorDraft.newMapping.shouldRestartShortcutRecording(afterChangingMouseButtonTo: 2) == false)
        #expect(ButtonMappingEditorDraft(mouseButtonNumber: 4, shortcut: nil).shouldRestartShortcutRecording(afterChangingMouseButtonTo: 5) == false)

        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        #expect(source.contains(#".onChange(of: mouseButtonNumber)"#))
        #expect(source.contains(#"restartRecording()"#))
    }

    @Test func macOSPresetShortcutsSeparateKeyboardShortcutsFromSystemActions() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let modelsURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Models")
            .appendingPathComponent("AppModels.swift")
        let source = try String(contentsOf: modelsURL, encoding: .utf8)

        #expect(source.contains("struct MacOSPresetShortcut"))
        #expect(source.contains("enum SystemMappingAction"))
        #expect(source.contains("struct MacOSSystemActionPreset"))
        #expect(source.contains(#"id: "spotlight""#))
        #expect(source.contains(#"id: "appSwitcher""#))
        #expect(source.contains(#"id: "hideApp""#))
        #expect(source.contains(#"id: "minimizeWindow""#))
        #expect(source.contains(#"id: "screenshotSelection""#))
        #expect(source.contains(#"action: .missionControl"#))
        #expect(source.contains(#"action: .currentAppWindows"#))
        #expect(source.contains(#"action: .spaceLeft"#))
        #expect(source.contains(#"action: .spaceRight"#))
        #expect(source.contains(#"action: .showDesktop"#))
        #expect(source.contains("case showDesktop"))
        #expect(source.contains("KeyboardShortcutDefinition(keyCode: 126, modifiersRawValue: CGEventFlags.maskControl.rawValue)") == false)
        #expect(source.contains("static func preset(matching shortcut: KeyboardShortcutDefinition)"))

        let titleValues = try localizedStringValues(for: "mapping.systemAction.missionControl")
        let descriptionValues = try localizedStringValues(for: "mapping.systemAction.missionControl.desc")
        #expect(titleValues["en"] == "Mission Control")
        #expect(titleValues["zh-Hans"] == "调度中心")
        #expect(descriptionValues["en"] == "Open Mission Control through the system Exposé service.")
        #expect(descriptionValues["zh-Hans"] == "通过系统 Exposé 服务打开调度中心。")

        let desktopTitleValues = try localizedStringValues(for: "mapping.systemAction.showDesktop")
        let desktopDescriptionValues = try localizedStringValues(for: "mapping.systemAction.showDesktop.desc")
        #expect(desktopTitleValues["en"] == "Show Desktop")
        #expect(desktopTitleValues["zh-Hans"] == "显示桌面")
        #expect(desktopDescriptionValues["en"] == "Show the desktop with the macOS Fn-H shortcut.")
        #expect(desktopDescriptionValues["zh-Hans"] == "使用 macOS Fn-H 快捷键显示桌面。")
    }

    @Test func systemActionRunnerUsesFunctionHForShowDesktop() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let serviceURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Services")
            .appendingPathComponent("EventEngines.swift")
        let source = try String(contentsOf: serviceURL, encoding: .utf8)
        let expectedShortcut = KeyboardShortcutDefinition(
            keyCode: 4,
            modifiersRawValue: CGEventFlags.maskSecondaryFn.rawValue
        )
        let plan = ShortcutEventPlanner().plan(for: expectedShortcut)

        #expect(source.contains("case .showDesktop:"))
        #expect(source.contains(#"fallbackShortcutPoster(fallbackShortcut)"#))
        #expect(source.contains(#"postDistributed("com.apple.showdesktop.awake")"#) == false)
        #expect(SystemMappingAction.showDesktop.fallbackShortcut == expectedShortcut)
        #expect(plan.map(\.keyCode) == [4, 4])
        #expect(plan.map(\.keyDown) == [true, false])
        #expect(plan.map(\.flagsRawValue) == [
            CGEventFlags.maskSecondaryFn.rawValue,
            CGEventFlags.maskSecondaryFn.rawValue
        ])
    }

    @Test func buttonMappingEditorSeparatesManualPresetAndSystemActionSelection() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let actionTypeValues = try localizedStringValues(for: "mapping.editor.actionType")
        let presetValues = try localizedStringValues(for: "mapping.editor.actionType.presetShortcut")
        let systemValues = try localizedStringValues(for: "mapping.editor.actionType.systemAction")

        #expect(source.contains(#"Picker("mapping.editor.actionType", selection: $actionSelection)"#))
        #expect(source.contains("MappingEditorActionSelection.manualRecord"))
        #expect(source.contains("MappingEditorActionSelection.presetShortcut"))
        #expect(source.contains("MappingEditorActionSelection.systemAction"))
        #expect(source.contains(#"Picker("mapping.editor.presetShortcut", selection: $presetShortcutID)"#))
        #expect(source.contains(#"Picker("mapping.editor.systemAction", selection: $systemActionID)"#))
        #expect(source.contains("MacOSPresetShortcut.allCases"))
        #expect(source.contains("MacOSSystemActionPreset.allCases"))
        #expect(source.contains("applyPresetShortcutSelection"))
        #expect(source.contains("applySystemActionSelection"))
        #expect(source.contains("cancelShortcutRecording()"))
        #expect(source.contains(#"presetShortcutID == MacOSPresetShortcut.customID"#) == false)
        #expect(actionTypeValues["en"] == "Action type")
        #expect(actionTypeValues["zh-Hans"] == "动作类型")
        #expect(presetValues["en"] == "Preset keyboard shortcut")
        #expect(presetValues["zh-Hans"] == "预制键盘快捷键")
        #expect(systemValues["en"] == "System action")
        #expect(systemValues["zh-Hans"] == "系统动作")
    }

    @Test func separateShortcutRecordingBuildsShortcutFromThreeIndependentKeys() {
        var session = ShortcutKeyAssemblySession()
        #expect(session.append(.modifier(keyCode: 55, flagRawValue: CGEventFlags.maskCommand.rawValue)) == .inProgress)
        #expect(session.append(.modifier(keyCode: 56, flagRawValue: CGEventFlags.maskShift.rawValue)) == .inProgress)
        #expect(session.append(.key(keyCode: 21)) == .complete(KeyboardShortcutDefinition(
            keyCode: 21,
            modifiersRawValue: CGEventFlags([.maskCommand, .maskShift]).rawValue
        )))
        #expect(session.keys.count == 3)
        #expect(session.append(.key(keyCode: 8)) == .full)
    }

    @Test func buttonMappingsCanStoreSystemActionsSeparatelyFromKeyboardShortcuts() throws {
        let systemMapping = ButtonMapping(mouseButtonNumber: 6, action: .systemAction(.missionControl))
        #expect(systemMapping.action == .systemAction(.missionControl))
        #expect(systemMapping.action.displayName == String(localized: "mapping.systemAction.missionControl"))
        #expect(systemMapping.action.keyboardShortcut == nil)

        let encoded = try JSONEncoder().encode(systemMapping)
        let decoded = try JSONDecoder().decode(ButtonMapping.self, from: encoded)
        #expect(decoded.action == .systemAction(.missionControl))
    }

    @Test func buttonMappingEditorTextFieldsSuspendShortcutRecording() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        #expect(source.contains("@FocusState private var focusedTextField: MappingEditorFocusedField?"))
        #expect(source.contains(#".focused($focusedTextField, equals: .name)"#))
        #expect(source.contains(#".focused($focusedTextField, equals: .note)"#))
        #expect(source.contains("focusedTextField == nil"))
        #expect(source.contains(#".onChange(of: focusedTextField)"#))
        #expect(source.contains("handleTextFieldFocusChange"))
    }

    @Test func shortcutRecorderOnlyTakesFocusWhileRecordingIsActive() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sharedViewsURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("SharedViews.swift")
        let source = try String(contentsOf: sharedViewsURL, encoding: .utf8)

        #expect(source.contains("focusIfNeeded(view)"))
        #expect(source.contains("guard view.isActive else { return }"))
        #expect(source.contains(#"DispatchQueue.main.async { view.window?.makeFirstResponder(view) }"#) == false)
    }

    @Test func sameShortcutCanBeUsedByDifferentMouseButtons() {
        let shortcut = KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        let existing = ButtonMapping(mouseButtonNumber: 4, shortcut: shortcut)
        let next = ButtonMapping(mouseButtonNumber: 5, shortcut: shortcut)
        #expect(ButtonMappingEngine().canInsert(next, into: [existing]))
    }

    @Test func mappingEngineFindsEnabledMapping() {
        let mapping = ButtonMapping(mouseButtonNumber: 6, shortcut: KeyboardShortcutDefinition(keyCode: 0, modifiersRawValue: CGEventFlags.maskCommand.rawValue))
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.buttonMappings = [mapping]
        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        #expect(ButtonMappingEngine().mapping(for: 6, config: config)?.mouseButtonNumber == 6)
    }

    @Test func disabledMappingIsExcludedFromRuntimeSnapshot() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.buttonMappings = [ButtonMapping(isEnabled: false, mouseButtonNumber: 6, shortcut: KeyboardShortcutDefinition(keyCode: 0, modifiersRawValue: 0))]
        let config = settings.runtimeSnapshot(permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized))
        #expect(config.buttonMappings.isEmpty)
    }

    @Test func settingsNormalizationDropsUnsupportedShortcutMappings() {
        let settings = AppSettings(
            buttonMappings: [
                ButtonMapping(
                    mouseButtonNumber: 6,
                    shortcut: KeyboardShortcutDefinition(keyCode: 999, modifiersRawValue: 0, displayName: "Key 999")
                )
            ]
        )

        #expect(settings.buttonMappings.isEmpty)
    }

    @Test func shortcutDisplayUsesMacSymbols() {
        let shortcut = KeyboardShortcutDefinition(
            keyCode: 8,
            modifiersRawValue: (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue)
        )
        #expect(shortcut.displayName == "⌘⇧C")
    }

    @Test func shortcutCaptureCancelsWithEscape() {
        let decision = ShortcutCaptureInterpreter().interpret(
            keyCode: 53,
            modifiersRawValue: CGEventFlags.maskCommand.rawValue
        )
        #expect(decision == .cancel)
    }

    @Test func shortcutCaptureClearsWithDelete() {
        let decision = ShortcutCaptureInterpreter().interpret(
            keyCode: 51,
            modifiersRawValue: CGEventFlags.maskCommand.rawValue
        )
        #expect(decision == .clear)
    }

    @Test func shortcutCaptureRejectsUnsupportedKeyCode() {
        let decision = ShortcutCaptureInterpreter().interpret(
            keyCode: 999,
            modifiersRawValue: CGEventFlags.maskCommand.rawValue
        )
        #expect(decision == .invalid)
    }

    @Test func mouseButtonRecordingCapturesFirstNewButtonWithinTimeout() {
        let session = MouseButtonRecordingSession(
            startedAt: Date(timeIntervalSince1970: 100),
            initialEventSequence: 10
        )
        #expect(session.capturedButton(from: MouseButtonCaptureEvent(buttonNumber: 4, sequence: 10), at: Date(timeIntervalSince1970: 101)) == nil)
        #expect(session.capturedButton(from: MouseButtonCaptureEvent(buttonNumber: 4, sequence: 11), at: Date(timeIntervalSince1970: 101)) == 4)
    }

    @Test func mouseButtonRecordingExpiresAfterFifteenSeconds() {
        let session = MouseButtonRecordingSession(
            startedAt: Date(timeIntervalSince1970: 100),
            initialEventSequence: nil
        )
        #expect(session.isActive(at: Date(timeIntervalSince1970: 114.9)))
        #expect(session.isActive(at: Date(timeIntervalSince1970: 115)) == false)
        #expect(session.capturedButton(from: MouseButtonCaptureEvent(buttonNumber: 7, sequence: 1), at: Date(timeIntervalSince1970: 115)) == nil)
    }

    @Test func shortcutRecordingSessionExpiresAfterFifteenSeconds() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let session = ShortcutRecordingSession(startedAt: startedAt)
        #expect(session.isActive(at: Date(timeIntervalSince1970: 114.9)))
        #expect(session.isActive(at: Date(timeIntervalSince1970: 115)) == false)
    }

    @Test func shortcutRecordingSessionCanRestart() {
        let session = ShortcutRecordingSession(startedAt: Date(timeIntervalSince1970: 100))
            .restarted(at: Date(timeIntervalSince1970: 200))
        #expect(session.isActive(at: Date(timeIntervalSince1970: 214.9)))
    }

    @Test func shortcutRecordingSessionCanCancelImmediately() {
        let session = ShortcutRecordingSession(startedAt: Date(timeIntervalSince1970: 100))
            .cancelled(at: Date(timeIntervalSince1970: 105))
        #expect(session.isActive(at: Date(timeIntervalSince1970: 105)) == false)
    }

    @Test func shortcutEventPlanPostsModifiersAroundMainKey() {
        let shortcut = KeyboardShortcutDefinition(
            keyCode: 8,
            modifiersRawValue: (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskControl.rawValue)
        )
        let plan = ShortcutEventPlanner().plan(for: shortcut)
        #expect(plan.map(\.keyCode) == [59, 55, 8, 8, 55, 59])
        #expect(plan.map(\.keyDown) == [true, true, true, false, false, false])
        #expect(plan[0].flagsRawValue == CGEventFlags.maskControl.rawValue)
        #expect(plan[1].flagsRawValue == (CGEventFlags.maskControl.rawValue | CGEventFlags.maskCommand.rawValue))
        #expect(plan[2].isMainKey)
        #expect(plan[3].isMainKey)
        #expect(plan.last?.flagsRawValue == 0)
    }

    @Test func keyboardShortcutInjectorUsesHIDProfileForSystemShortcuts() {
        let profile = ShortcutPostingProfile.globalKeyboardShortcut
        #expect(profile.sourceStateID == .hidSystemState)
        #expect(profile.tapLocation == .cghidEventTap)
        #expect(profile.interEventDelayMicroseconds == 10_000)
    }

    @Test func controlShortcutsUseKeyboardEventsAfterMouseButtonRelease() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let serviceURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Services")
            .appendingPathComponent("EventEngines.swift")
        let source = try String(contentsOf: serviceURL, encoding: .utf8)
        let missionControl = KeyboardShortcutDefinition(keyCode: 126, modifiersRawValue: CGEventFlags.maskControl.rawValue)
        let plan = ShortcutEventPlanner().plan(for: missionControl)

        #expect(plan.map(\.keyCode) == [59, 126, 126, 59])
        #expect(source.contains("SystemShortcutResolver") == false)
        #expect(source.contains("case .keyboardShortcut(let shortcut):"))
        #expect(source.contains("case .systemAction(let action):"))
        #expect(source.contains("SystemActionRunner"))
        #expect(source.contains("if type == .otherMouseUp"))
        #expect(source.contains("usleep(postingProfile.interEventDelayMicroseconds)"))
        #expect(source.contains("if type == .otherMouseDown {\n            shortcutInjector.post") == false)
    }

    @Test func eventTapRecoveryRetriesTimeoutAndUserInputDisables() {
        var policy = EventTapRecoveryPolicy()
        #expect(policy.recordDisabled(reason: .timeout) == .reenable(after: 0.25))
        #expect(policy.recordDisabled(reason: .userInput) == .reenable(after: 1.0))
    }

    @Test func eventTapDisableReasonsUseLocalizedDiagnosticMessageKeys() {
        #expect(EventTapDisableReason.timeout.diagnosticMessageKey == "diagnostics.log.eventTapDisabledByTimeout")
        #expect(EventTapDisableReason.userInput.diagnosticMessageKey == "diagnostics.log.eventTapDisabledByUserInput")
    }

    @Test func inputEventSummariesUseLocalizationKeys() {
        #expect(InputEventSummary.trackpadScroll.localizationKey == "diagnostics.event.trackpadScroll")
        #expect(InputEventSummary.physicalMouseWheel.localizationKey == "diagnostics.event.physicalMouseWheel")
        #expect(InputEventSummary.mouseButton(4).localizationKey == "diagnostics.event.mouseButton")
        #expect(InputEventSummary.mouseButton(4).argument == 4)
    }

    @Test func inputEventSummaryRateLimiterThrottlesRepeatedScrollButKeepsButtonEventsImmediate() {
        var limiter = InputEventSummaryRateLimiter(minimumInterval: 0.25)
        let firstScroll = limiter.shouldEmit(.physicalMouseWheel, now: 10.00)
        let repeatedScroll = limiter.shouldEmit(.physicalMouseWheel, now: 10.10)
        let delayedScroll = limiter.shouldEmit(.physicalMouseWheel, now: 10.25)
        let changedScrollKind = limiter.shouldEmit(.trackpadScroll, now: 10.26)
        let repeatedTrackpadScroll = limiter.shouldEmit(.trackpadScroll, now: 10.30)
        let firstButton = limiter.shouldEmit(.mouseButton(4), now: 10.31)
        let repeatedButton = limiter.shouldEmit(.mouseButton(4), now: 10.32)

        #expect(firstScroll)
        #expect(repeatedScroll == false)
        #expect(delayedScroll)
        #expect(changedScrollKind)
        #expect(repeatedTrackpadScroll == false)
        #expect(firstButton)
        #expect(repeatedButton)
    }

    @Test func diagnosticDisplayValueRecognizesLocalizedKeysButPreservesPlainMessages() {
        #expect(DiagnosticDisplayValue("diagnostics.log.eventTapDisabledByTimeout").isLocalizationKey)
        #expect(DiagnosticDisplayValue("mapping.duplicateMouseButton").isLocalizationKey)
        #expect(DiagnosticDisplayValue("settings_load_corrupt").isLocalizationKey == false)
        #expect(DiagnosticDisplayValue("Cannot create event tap").isLocalizationKey == false)
    }

    @Test func eventTapSetupErrorsExposeLocalizedDiagnosticMessageKeys() {
        #expect(EventTapError.cannotCreateTap.diagnosticMessageKey == "diagnostics.error.cannotCreateEventTap")
        #expect(EventTapError.cannotCreateRunLoopSource.diagnosticMessageKey == "diagnostics.error.cannotCreateRunLoopSource")
    }

    @Test func eventTapMaskAvoidsGlobalKeyboardEvents() {
        let mask = EventTapService.eventsOfInterestMask

        #expect(mask.containsEvent(.scrollWheel))
        #expect(mask.containsEvent(.otherMouseDown))
        #expect(mask.containsEvent(.otherMouseUp))
        #expect(mask.containsEvent(.keyDown) == false)
        #expect(mask.containsEvent(.keyUp) == false)
        #expect(mask.containsEvent(.flagsChanged) == false)
        #expect(mask.containsEvent(.mouseMoved) == false)
    }

    @Test func eventTapRecoveryStopsAfterRepeatedDisables() {
        var policy = EventTapRecoveryPolicy()
        _ = policy.recordDisabled(reason: .timeout)
        _ = policy.recordDisabled(reason: .timeout)
        #expect(policy.recordDisabled(reason: .timeout) == .stopWithFailure(message: "diagnostics.log.eventTapDisabledRepeatedly"))
        policy.recordSuccessfulStart()
        #expect(policy.consecutiveDisables == 0)
    }

    @Test func eventTapPerformanceRecorderReportsAverageAndP95() {
        let recorder = EventTapPerformanceRecorder(maxSamples: 5)
        recorder.record(callbackDuration: 0.0005)
        recorder.record(callbackDuration: 0.001)
        recorder.record(callbackDuration: 0.003)
        let snapshot = recorder.snapshot()
        #expect(snapshot.eventCount == 3)
        #expect(abs(snapshot.averageCallbackMilliseconds - 1.5) < 0.001)
        #expect(abs(snapshot.p95CallbackMilliseconds - 3.0) < 0.001)
        #expect(snapshot.exceedsTarget)
    }

    @Test func diagnosticsExportIncludesErrorCodeAndPerformanceStats() throws {
        let export = DiagnosticsExport(
            appVersion: "1.0",
            build: "1",
            macOS: "macOS 26",
            architecture: "arm64",
            permissions: .unknown,
            loginItemStatus: .unknown,
            eventTapStatus: .disabledByTimeout,
            lastErrorCode: EventTapRuntimeStatus.disabledByTimeout.diagnosticsErrorCode,
            performance: EventTapPerformanceSnapshot(
                eventCount: 2,
                averageCallbackMilliseconds: 0.4,
                p95CallbackMilliseconds: 0.8,
                exceedsTarget: false
            ),
            devices: [],
            conflictingInputTools: [],
            settingsSummary: DiagnosticsSettingsSummary(settings: .defaults),
            recentLogs: []
        )
        let data = try JSONEncoder.pretty.encode(export)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["lastErrorCode"] as? String == "event_tap_disabled_by_timeout")
        let performance = try #require(object["performance"] as? [String: Any])
        #expect(performance["eventCount"] as? Int == 2)
        #expect(performance["exceedsTarget"] as? Bool == false)
    }

    @Test func permissionsDiagnosticsPageListsRecognizedDevices() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("PermissionsDiagnosticsPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "diagnostics.noDevices")

        #expect(source.contains(#"Section("diagnostics.devices")"#))
        #expect(source.contains(#"ForEach(appState.devices)"#))
        #expect(source.contains("DeviceDetailGrid(summary:"))
        #expect(source.contains(#"Text("diagnostics.noDevices")"#))
        #expect(values["en"] == "No recognized devices yet.")
        #expect(values["zh-Hans"] == "暂未识别到设备。")
    }

    @Test func permissionsDiagnosticsActionButtonsExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("PermissionsDiagnosticsPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let recheckHint = try localizedStringValues(for: "permissions.recheck.hint")
        let inputHint = try localizedStringValues(for: "permissions.openInputMonitoring.hint")
        let accessibilityHint = try localizedStringValues(for: "permissions.openAccessibility.hint")
        let exportHint = try localizedStringValues(for: "diagnostics.exportButton.hint")

        #expect(source.contains(#".accessibilityLabel(Text("permissions.recheck"))"#))
        #expect(source.contains(#".accessibilityHint(Text("permissions.recheck.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("permissions.openInputMonitoring"))"#))
        #expect(source.contains(#".accessibilityHint(Text("permissions.openInputMonitoring.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("permissions.openAccessibility"))"#))
        #expect(source.contains(#".accessibilityHint(Text("permissions.openAccessibility.hint"))"#))
        #expect(source.contains(#".accessibilityLabel(Text("diagnostics.exportButton"))"#))
        #expect(source.contains(#".accessibilityHint(Text("diagnostics.exportButton.hint"))"#))

        #expect(recheckHint["en"] == "Refresh permission, login item, device, and event listener status.")
        #expect(recheckHint["zh-Hans"] == "刷新权限、登录项、设备和事件监听状态。")
        #expect(inputHint["en"] == "Open System Settings to grant or remove Input Monitoring permission.")
        #expect(inputHint["zh-Hans"] == "打开系统设置，用于授予或移除输入监控权限。")
        #expect(accessibilityHint["en"] == "Open System Settings to grant or remove Accessibility permission.")
        #expect(accessibilityHint["zh-Hans"] == "打开系统设置，用于授予或移除辅助功能权限。")
        #expect(exportHint["en"] == "Export a local diagnostics package without typed text or input contents.")
        #expect(exportHint["zh-Hans"] == "导出不包含键入文本或输入内容的本机诊断包。")
    }

    @Test func welcomeOnboardingButtonsExposeVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("WelcomeOnboardingView.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)

        let backHint = try localizedStringValues(for: "onboarding.back.hint")
        let nextHint = try localizedStringValues(for: "onboarding.next.hint")
        let enterSettingsHint = try localizedStringValues(for: "onboarding.enterSettings.hint")

        for key in [
            "permissions.openInputMonitoring",
            "permissions.openAccessibility",
            "permissions.recheck",
            "onboarding.back",
            "onboarding.next",
            "onboarding.enterSettings"
        ] {
            #expect(source.contains(#".accessibilityLabel(Text("\#(key)"))"#))
        }
        for key in [
            "permissions.openInputMonitoring.hint",
            "permissions.openAccessibility.hint",
            "permissions.recheck.hint",
            "onboarding.back.hint",
            "onboarding.next.hint",
            "onboarding.enterSettings.hint"
        ] {
            #expect(source.contains(#".accessibilityHint(Text("\#(key)"))"#))
        }
        #expect(backHint["en"] == "Return to the previous onboarding step.")
        #expect(backHint["zh-Hans"] == "返回上一个引导步骤。")
        #expect(nextHint["en"] == "Continue to the next onboarding step.")
        #expect(nextHint["zh-Hans"] == "继续下一个引导步骤。")
        #expect(enterSettingsHint["en"] == "Finish onboarding and open settings.")
        #expect(enterSettingsHint["zh-Hans"] == "完成引导并打开设置。")
    }

    @Test func permissionActionButtonsExposeSpecificVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("PermissionsDiagnosticsPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let inputLabel = try localizedStringValues(for: "permissions.request.inputMonitoring")
        let accessibilityLabel = try localizedStringValues(for: "permissions.request.accessibility")
        let inputHint = try localizedStringValues(for: "permissions.request.inputMonitoring.hint")
        let accessibilityHint = try localizedStringValues(for: "permissions.request.accessibility.hint")

        #expect(source.contains(#".accessibilityLabel(Text(LocalizedStringKey(permissionActionLabelKey)))"#))
        #expect(source.contains(#".accessibilityHint(Text(LocalizedStringKey(permissionActionHintKey)))"#))
        #expect(inputLabel["en"] == "Request Input Monitoring permission")
        #expect(inputLabel["zh-Hans"] == "请求输入监控权限")
        #expect(accessibilityLabel["en"] == "Request Accessibility permission")
        #expect(accessibilityLabel["zh-Hans"] == "请求辅助功能权限")
        #expect(inputHint["en"] == "Opens the system prompt or settings for reading mouse and keyboard events.")
        #expect(inputHint["zh-Hans"] == "打开系统提示或设置，用于读取鼠标和键盘事件。")
        #expect(accessibilityHint["en"] == "Opens the system prompt or settings for changing and sending configured input events.")
        #expect(accessibilityHint["zh-Hans"] == "打开系统提示或设置，用于改写和发送已配置的输入事件。")
    }

    @Test func diagnosticsRowsExposeCombinedVoiceOverLabelsAndHints() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("PermissionsDiagnosticsPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let values = try localizedStringValues(for: "diagnostics.row.accessibilityHint")

        #expect(source.components(separatedBy: #".accessibilityElement(children: .combine)"#).count - 1 >= 4)
        #expect(source.components(separatedBy: #".accessibilityHint(Text("diagnostics.row.accessibilityHint"))"#).count - 1 >= 4)
        #expect(values["en"] == "Diagnostic value. Read the label and current value together.")
        #expect(values["zh-Hans"] == "诊断值。请连同标签和当前值一起读取。")
    }

    @Test func permissionResetInstructionsMentionBothRequiredPermissions() {
        let instructions = PermissionResetInstructions.default
        #expect(instructions.titleKey == "permissions.reset.title")
        #expect(instructions.bodyKey == "permissions.reset.body")
        #expect(instructions.affectedPermissionKinds == [.inputMonitoring, .accessibility])
    }

    @Test func permissionSummaryRequiresBothPermissions() {
        #expect(PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized).canProcessEvents)
        #expect(PermissionSummary(inputMonitoring: .authorized, accessibility: .denied).canProcessEvents == false)
    }

    @Test func eventTapReportsMissingPermissionsWhenConfigCannotProcessEvents() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        let config = settings.runtimeSnapshot(
            permissions: PermissionSummary(inputMonitoring: .denied, accessibility: .authorized)
        )
        let service = EventTapService()
        let recorder = EventTapStatusRecorder()
        service.statusHandler = { status, _ in recorder.append(status) }

        service.updateConfig(config)

        #expect(recorder.last == .missingPermissions)
    }

    @Test func eventTapStartReportsStoppedWhenMasterSwitchIsOff() {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        settings.masterEnabled = false
        let config = settings.runtimeSnapshot(
            permissions: PermissionSummary(inputMonitoring: .authorized, accessibility: .authorized)
        )
        let service = EventTapService()
        let recorder = EventTapStatusRecorder()
        service.statusHandler = { status, _ in recorder.append(status) }

        try? service.start(with: config)

        #expect(recorder.last == .stopped)
    }

    @Test func permissionStateCanRepresentRestartRequired() throws {
        #expect(PermissionState.requiresRestart.titleKey == "permission.requiresRestart")
        #expect(PermissionSummary(inputMonitoring: .requiresRestart, accessibility: .authorized).canProcessEvents == false)

        let values = try localizedStringValues(for: "permission.requiresRestart")
        #expect(values["en"] == "Restart required")
        #expect(values["zh-Hans"] == "需要重启 App")
    }

    @Test func permissionStateActionHintExplainsRestartRequired() throws {
        #expect(PermissionStateActionHint.messageKey(for: .authorized) == nil)
        #expect(PermissionStateActionHint.messageKey(for: .denied) == "permissions.actionHint.denied")
        #expect(PermissionStateActionHint.messageKey(for: .requiresRestart) == "permissions.actionHint.requiresRestart")
        #expect(PermissionStateActionHint.messageKey(for: .unknown) == "permissions.actionHint.unknown")

        let values = try localizedStringValues(for: "permissions.actionHint.requiresRestart")
        #expect(values["en"] == "Quit and reopen ScrollBridge for the new permission to take effect.")
        #expect(values["zh-Hans"] == "请退出并重新打开 ScrollBridge，让新权限生效。")
    }

    @Test func permissionStateResolverMarksRestartRequiredAfterUserVisitsPermissionSettings() {
        #expect(PermissionStateResolver.state(isAuthorized: true, hasRequestedOrOpenedSettings: false) == .authorized)
        #expect(PermissionStateResolver.state(isAuthorized: false, hasRequestedOrOpenedSettings: false) == .denied)
        #expect(PermissionStateResolver.state(isAuthorized: false, hasRequestedOrOpenedSettings: true) == .requiresRestart)
        #expect(PermissionStateResolver.state(isAuthorized: nil, hasRequestedOrOpenedSettings: true) == .unknown)
    }

    @Test func deviceIdentifierUsesVendorProductAndName() {
        let id = HIDDeviceService.deviceIdentifier(name: "Mouse", vendorID: 12, productID: 34)
        #expect(id == "12:34:Mouse")
    }

    @Test func deviceClassifierCoversMagicMouseTrackpadMouseAndUnknown() {
        let classifier = HIDDeviceClassifier()

        let magicMouse = classifier.classify(name: "Apple Magic Mouse", usagePage: 1, usage: 2)
        #expect(magicMouse.kind == .magicMouse)
        #expect(magicMouse.confidence >= 0.9)

        let trackpad = classifier.classify(name: "Apple Internal Trackpad", usagePage: 1, usage: 2)
        #expect(trackpad.kind == .trackpad)
        #expect(trackpad.confidence >= 0.9)

        let standardMouse = classifier.classify(name: "USB Mouse", usagePage: 1, usage: 2)
        #expect(standardMouse.kind == .mouse)
        #expect(standardMouse.isStandardHID)

        let unknown = classifier.classify(name: "Vendor Device", usagePage: nil, usage: nil)
        #expect(unknown.kind == .unknown)
        #expect(unknown.confidence < 0.65)
    }

    @Test func deviceClassifierAppliesManualOverrideWithFullConfidence() {
        let classifier = HIDDeviceClassifier()
        let detected = classifier.classify(name: "USB Mouse", usagePage: 1, usage: 2)
        let resolved = classifier.resolve(deviceID: "mouse-1", detected: detected, overrides: ["mouse-1": .ignored])

        #expect(resolved.kind == .ignored)
        #expect(resolved.confidence == 1.0)
        #expect(resolved.isStandardHID == detected.isStandardHID)
    }

    @Test func deviceDisplaySummaryIncludesRequiredDiagnosticsFields() {
        let device = DeviceProfile(
            id: "12:34:Mouse",
            name: "Mouse",
            vendorID: 12,
            productID: 34,
            transport: "USB",
            usagePage: 1,
            usage: 2,
            isStandardHID: true,
            kind: .mouse,
            confidence: 0.9,
            lastEventDescription: "12:00:00"
        )
        let summary = DeviceProfileDisplaySummary(device: device)
        #expect(summary.identityLine == "12 · 34 · USB")
        #expect(summary.usageLine == "1 · 2")
        #expect(summary.standardHIDKey == "devices.standardHID.yes")
        #expect(summary.confidenceLine == "90%")
        #expect(summary.lastEventLine == "12:00:00")
    }

    @Test func devicesRefreshButtonExposesVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("DevicesPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "devices.refresh")
        let hintValues = try localizedStringValues(for: "devices.refresh.hint")

        #expect(source.contains(#"Button("devices.refresh") { appState.refreshDevices() }"#))
        #expect(source.contains(#".accessibilityLabel(Text("devices.refresh"))"#))
        #expect(source.contains(#".accessibilityHint(Text("devices.refresh.hint"))"#))
        #expect(labelValues["en"] == "Refresh")
        #expect(labelValues["zh-Hans"] == "刷新")
        #expect(hintValues["en"] == "Refresh the connected device list and classification status.")
        #expect(hintValues["zh-Hans"] == "刷新已连接设备列表和分类状态。")
    }

    @Test func deviceRowsExposeVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("DevicesPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "devices.row.accessibilityLabelFormat")
        let hintValues = try localizedStringValues(for: "devices.row.accessibilityHint")

        #expect(source.contains(#".accessibilityElement(children: .combine)"#))
        #expect(source.contains(#".accessibilityLabel(Text(deviceAccessibilityLabel(for: device)))"#))
        #expect(source.contains(#".accessibilityHint(Text("devices.row.accessibilityHint"))"#))
        #expect(labelValues["en"] == "Device %@, kind %@, identity %@, usage %@, standard HID %@, confidence %@, last event %@")
        #expect(labelValues["zh-Hans"] == "设备 %@，分类 %@，标识 %@，用途 %@，标准 HID %@，置信度 %@，最近事件 %@")
        #expect(hintValues["en"] == "Use the picker to override how ScrollBridge treats this device.")
        #expect(hintValues["zh-Hans"] == "使用选择器调整 ScrollBridge 对此设备的处理方式。")
    }

    @Test func deviceKindPickerExposesVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("DevicesPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "devices.kind")
        let hintValues = try localizedStringValues(for: "devices.kind.hint")

        #expect(source.contains(#".accessibilityLabel(Text("devices.kind"))"#))
        #expect(source.contains(#".accessibilityHint(Text("devices.kind.hint"))"#))
        #expect(labelValues["en"] == "Device kind")
        #expect(labelValues["zh-Hans"] == "设备类型")
        #expect(hintValues["en"] == "Choose whether this device is treated as a mouse, trackpad, Magic Mouse, keyboard, ignored, or unknown.")
        #expect(hintValues["zh-Hans"] == "选择将此设备视为鼠标、触控板、Magic Mouse、键盘、忽略或未知设备。")
    }

    @Test func lowConfidenceDeviceDisplaySummaryRequestsManualConfirmation() {
        let device = DeviceProfile(
            id: "-1:-1:Unknown",
            name: "Unknown",
            kind: .mouse,
            confidence: 0.4
        )
        let summary = DeviceProfileDisplaySummary(device: device)

        #expect(summary.confirmationKey == "devices.classificationNeedsConfirmation")
    }

    @Test func conflictDetectorFindsCommonInputTools() {
        let apps = [
            RunningApplicationSnapshot(localizedName: "Karabiner-Elements", bundleIdentifier: "org.pqrs.Karabiner-Elements"),
            RunningApplicationSnapshot(localizedName: "Notes", bundleIdentifier: "com.apple.Notes"),
            RunningApplicationSnapshot(localizedName: "Logi Options+", bundleIdentifier: "com.logitech.manager")
        ]
        let conflicts = InputToolConflictDetector().detect(in: apps)
        #expect(conflicts.map(\.name).contains("Karabiner-Elements"))
        #expect(conflicts.map(\.name).contains("Logi Options+"))
        #expect(conflicts.map(\.name).contains("Notes") == false)
    }

    @Test func conflictDetectorDeduplicatesByBundleIdentifier() {
        let apps = [
            RunningApplicationSnapshot(localizedName: "Mos", bundleIdentifier: "com.caldis.Mos"),
            RunningApplicationSnapshot(localizedName: "Mos Helper", bundleIdentifier: "com.caldis.Mos")
        ]
        let conflicts = InputToolConflictDetector().detect(in: apps)
        #expect(conflicts.count == 1)
    }

    @Test func buttonMappingMissingScopeDecodesAsGlobal() throws {
        let data = #"{"id":"00000000-0000-0000-0000-000000000001","isEnabled":true,"mouseButtonNumber":6,"shortcut":{"keyCode":8,"modifiersRawValue":1048576,"displayName":"⌘C"},"note":"Copy"}"#.data(using: .utf8)!
        let mapping = try JSONDecoder().decode(ButtonMapping.self, from: data)
        #expect(mapping.scope == "global")
        #expect(mapping.note == "Copy")
    }

    @Test func buttonMappingListSummaryIncludesScopeAndNote() {
        let mapping = ButtonMapping(
            mouseButtonNumber: 6,
            shortcut: KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue),
            scope: "global",
            note: "Copy selection"
        )
        let summary = ButtonMappingListSummary(mapping: mapping)
        #expect(summary.scopeKey == "mapping.scope.global")
        #expect(summary.note == "Copy selection")
    }

    @Test func buttonMappingListSummaryIncludesTrimmedCustomName() {
        let mapping = ButtonMapping(
            name: " Copy side button ",
            mouseButtonNumber: 6,
            shortcut: KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue),
            scope: "global",
            note: "Copy selection"
        )
        let summary = ButtonMappingListSummary(mapping: mapping)
        #expect(mapping.name == "Copy side button")
        #expect(summary.name == "Copy side button")
    }

    @Test func buttonMappingRowsExposeVoiceOverLabelAndHint() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Views")
            .appendingPathComponent("ButtonMappingPage.swift")
        let source = try String(contentsOf: pageURL, encoding: .utf8)
        let labelValues = try localizedStringValues(for: "mapping.row.accessibilityLabelFormat")
        let hintValues = try localizedStringValues(for: "mapping.row.accessibilityHint")

        #expect(source.contains(#".accessibilityElement(children: .combine)"#))
        #expect(source.contains(#".accessibilityLabel(Text(mappingAccessibilityLabel(for: mapping)))"#))
        #expect(source.contains(#".accessibilityHint(Text("mapping.row.accessibilityHint"))"#))
        #expect(labelValues["en"] == "Button %d, shortcut %@, scope %@, note %@")
        #expect(labelValues["zh-Hans"] == "按钮 %d，快捷键 %@，作用范围 %@，备注 %@")
        #expect(hintValues["en"] == "Use Edit to change this mapping, or Delete to remove it.")
        #expect(hintValues["zh-Hans"] == "使用编辑修改此映射，或使用删除移除此映射。")
    }

    @Test func buttonMappingMissingNameDecodesAsEmptyForMigration() throws {
        let data = #"{"id":"00000000-0000-0000-0000-000000000001","isEnabled":true,"mouseButtonNumber":6,"shortcut":{"keyCode":8,"modifiersRawValue":1048576,"displayName":"⌘C"},"scope":"global","note":"Copy"}"#.data(using: .utf8)!
        let mapping = try JSONDecoder().decode(ButtonMapping.self, from: data)
        #expect(mapping.name == "")
        #expect(ButtonMappingListSummary(mapping: mapping).name == nil)
    }

    @Test func settingsPersistenceRoundTrip() throws {
        let suiteName = "MouseBridgeTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let persistence = SettingsPersistence(defaults: suite)
        var settings = AppSettings.defaults
        settings.smoothSteps = 13
        settings.language = .en
        settings.hasCompletedOnboarding = true
        persistence.save(settings)
        let loaded = persistence.load()
        #expect(loaded.smoothSteps == 13)
        #expect(loaded.language == .en)
        #expect(loaded.hasCompletedOnboarding)
    }

    @Test func settingsPersistenceMigratesLegacySchemaAndPreservesMappings() throws {
        let suiteName = "MouseBridgeTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let persistence = SettingsPersistence(defaults: suite)
        let legacy = #"{"schemaVersion":0,"smoothSteps":7,"buttonMappings":[{"id":"00000000-0000-0000-0000-000000000001","isEnabled":true,"mouseButtonNumber":6,"shortcut":{"keyCode":8,"modifiersRawValue":1048576,"displayName":"⌘C"},"note":"Copy"}]}"#.data(using: .utf8)!
        suite.set(legacy, forKey: SettingsPersistence.storageKey)

        let loaded = persistence.load()

        #expect(loaded.schemaVersion == AppSettings.currentSchemaVersion)
        #expect(loaded.smoothSteps == 7)
        #expect(loaded.buttonMappings.count == 1)
        #expect(loaded.buttonMappings.first?.mouseButtonNumber == 6)
        #expect(persistence.lastLoadErrorCode == nil)
    }

    @Test func settingsPersistenceBacksUpInvalidJSONAndReportsLoadError() {
        let suiteName = "MouseBridgeTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let persistence = SettingsPersistence(defaults: suite)
        let invalidData = Data("not-json".utf8)
        suite.set(invalidData, forKey: SettingsPersistence.storageKey)

        let loaded = persistence.load()
        let backupKeys = suite.dictionaryRepresentation().keys.filter { $0.hasPrefix(SettingsPersistence.corruptBackupPrefix) }

        #expect(loaded == .defaults)
        #expect(persistence.lastLoadErrorCode == "settings_load_corrupt")
        #expect(backupKeys.count == 1)
        #expect(suite.data(forKey: backupKeys[0]) == invalidData)
    }

    @Test @MainActor func appStateReportsCorruptSettingsAsDiagnosticErrorCode() {
        let suiteName = "MouseBridgeTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        suite.set(Data("not-json".utf8), forKey: SettingsPersistence.storageKey)

        let appState = AppState(persistence: SettingsPersistence(defaults: suite))

        #expect(appState.lastError == "settings_load_corrupt")
        #expect(appState.lastErrorCode == "settings_load_corrupt")
    }

    @Test @MainActor func appStateDiagnosticsLogsUseLocalizationKeysForAppAuthoredMessages() {
        let suiteName = "MouseBridgeTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let appState = AppState(persistence: SettingsPersistence(defaults: suite))

        appState.completeOnboarding()

        #expect(appState.logs.first?.message == "diagnostics.log.onboardingCompleted")
    }

    @Test @MainActor func appStatePreparesEventTapForTermination() {
        let suiteName = "MouseBridgeTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let appState = AppState(persistence: SettingsPersistence(defaults: suite))

        appState.prepareForTermination()

        #expect(appState.eventTapStatus == .stopped)
        #expect(appState.logs.first?.message == "diagnostics.log.appWillTerminate")
    }

    @Test func missingFieldsDecodeWithCurrentDefaults() throws {
        let data = #"{"smoothSteps":11,"language":"zhHans"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.smoothSteps == 11)
        #expect(decoded.language == .zhHans)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.buttonMappings.count == 2)
        #expect(decoded.excludedBundleIdentifiers.isEmpty)
    }

    private func infoPlistStrings(localeDirectoryName: String) throws -> [String: String] {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stringsURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Resources")
            .appendingPathComponent(localeDirectoryName)
            .appendingPathComponent("InfoPlist.strings")
        let data = try Data(contentsOf: stringsURL)
        let object = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        return object
    }

    private func localizedStringValues(for key: String) throws -> [String: String] {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
            .appendingPathComponent("MouseBridge")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(object["strings"] as? [String: Any])
        let entry = try #require(strings[key] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: Any])
        return localizations.reduce(into: [String: String]()) { result, item in
            guard let localization = item.value as? [String: Any],
                  let stringUnit = localization["stringUnit"] as? [String: Any],
                  let value = stringUnit["value"] as? String else {
                return
            }
            result[item.key] = value
        }
    }
}
