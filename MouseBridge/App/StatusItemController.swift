import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let appState: AppState
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState
        super.init()
        appState.bootstrap()
        configureStateObservation()
        refreshStatusItem()
        openInitialSettingsWindowIfNeeded()
    }

    private func configureStateObservation() {
        appState.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshStatusItem()
                    self?.updateWindowTitles()
                }
            }
            .store(in: &cancellables)
    }

    private func openInitialSettingsWindowIfNeeded() {
        guard !appState.hasRequestedInitialSettingsWindow else { return }
        if appState.shouldOpenSettingsAtLaunch {
            openSettingsWindow()
        }
        appState.markInitialSettingsWindowRequestHandled()
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard appState.shouldInsertMenuBarExtra else {
            removeStatusItem()
            return
        }

        let statusItem = ensureStatusItem()
        guard let button = statusItem.button else { return }
        let imageName = appState.permissions.canProcessEvents ? "computermouse" : "computermouse.fill"
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: localized("app.name"))
        image?.isTemplate = true
        button.image = image
        button.toolTip = localized("app.name")
    }

    private func ensureStatusItem() -> NSStatusItem {
        if let statusItem {
            return statusItem
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = statusItem
        return statusItem
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let statusItem, let button = statusItem.button else { return }
        statusItem.menu = makeMenu()
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(disabledItem("app.name"))
        menu.addItem(.separator())
        menu.addItem(disabledItem(appState.menuStatusKey))
        menu.addItem(toggleItem(
            "menu.reverseMouseWheel",
            action: #selector(toggleReverseMouseWheel),
            isOn: appState.settings.reverseMouseWheelEnabled
        ))
        menu.addItem(toggleItem(
            "menu.smoothScrolling",
            action: #selector(toggleSmoothScrolling),
            isOn: appState.settings.smoothScrollingEnabled
        ))
        menu.addItem(toggleItem(
            "menu.buttonMapping",
            action: #selector(toggleButtonMapping),
            isOn: appState.settings.buttonMappingEnabled
        ))

        if !appState.permissions.canProcessEvents {
            menu.addItem(actionItem("menu.openPermissionGuide", action: #selector(openPermissionGuide)))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("menu.openSettings", action: #selector(openSettingsFromMenu)))
        menu.addItem(actionItem("menu.permissionsDiagnostics", action: #selector(openPermissionsDiagnostics)))
        menu.addItem(actionItem("menu.about", action: #selector(openAbout)))
        menu.addItem(.separator())
        menu.addItem(actionItem("menu.quit", action: #selector(quit)))

        return menu
    }

    private func disabledItem(_ titleKey: String) -> NSMenuItem {
        let item = NSMenuItem(title: localized(titleKey), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ titleKey: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: localized(titleKey), action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        return item
    }

    private func toggleItem(_ titleKey: String, action: Selector, isOn: Bool) -> NSMenuItem {
        let item = actionItem(titleKey, action: action)
        item.state = isOn ? .on : .off
        return item
    }

    @objc private func toggleReverseMouseWheel() {
        appState.updateSettings { settings in
            settings.reverseMouseWheelEnabled.toggle()
        }
    }

    @objc private func toggleSmoothScrolling() {
        appState.updateSettings { settings in
            settings.smoothScrollingEnabled.toggle()
        }
    }

    @objc private func toggleButtonMapping() {
        appState.updateSettings { settings in
            settings.buttonMappingEnabled.toggle()
        }
    }

    @objc private func openPermissionGuide() {
        openSettings(page: .permissions)
    }

    @objc private func openSettingsFromMenu() {
        openSettings(page: nil)
    }

    @objc private func openPermissionsDiagnostics() {
        openSettings(page: .permissions)
    }

    @objc private func openAbout() {
        openAboutWindow()
    }

    @objc private func quit() {
        appState.prepareForTermination()
        NSApplication.shared.terminate(nil)
    }

    private func openSettings(page: SettingsPage?) {
        if let page {
            appState.requestSettingsPage(page)
        }
        openSettingsWindow()
    }

    private func openSettingsWindow() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func openAboutWindow() {
        let window = aboutWindow ?? makeAboutWindow()
        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeSettingsWindow() -> NSWindow {
        let view = SettingsStatusWindowRootView()
            .environmentObject(appState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = localized("window.settings")
        window.contentView = NSHostingView(rootView: view)
        window.minSize = NSSize(width: 760, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }

    private func makeAboutWindow() -> NSWindow {
        let view = AboutStatusWindowRootView()
            .environmentObject(appState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = localized("window.about")
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }

    private func updateWindowTitles() {
        settingsWindow?.title = localized("window.settings")
        aboutWindow?.title = localized("window.about")
    }

    private func localized(_ key: String) -> String {
        guard let identifier = appState.settings.language.localeIdentifier,
              let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(key, comment: "")
        }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

private struct SettingsStatusWindowRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBootstrapView {
            SettingsRootView()
                .environmentObject(appState)
                .environment(\.locale, appState.locale)
        }
        .environmentObject(appState)
        .frame(minWidth: 760, minHeight: 500)
    }
}

private struct AboutStatusWindowRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBootstrapView {
            AboutPage()
                .environmentObject(appState)
                .environment(\.locale, appState.locale)
                .frame(width: 520, height: 460)
        }
        .environmentObject(appState)
    }
}
