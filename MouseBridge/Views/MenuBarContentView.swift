import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label("app.name", systemImage: appState.permissions.canProcessEvents ? "computermouse" : "computermouse.fill")
            .onAppear {
                guard !appState.hasRequestedInitialSettingsWindow else { return }
                appState.bootstrap()
                if appState.shouldOpenSettingsAtLaunch {
                    DispatchQueue.main.async {
                        openWindow(id: AppWindow.settings.rawValue)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        appState.markInitialSettingsWindowRequestHandled()
                    }
                } else {
                    appState.markInitialSettingsWindowRequestHandled()
                }
            }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Text("app.name")
                .font(.headline)
            Divider()
            Text(LocalizedStringKey(appState.menuStatusKey))
            Toggle(isOn: binding(\.reverseMouseWheelEnabled)) {
                Text("menu.reverseMouseWheel")
            }
            .accessibilityLabel(Text("menu.reverseMouseWheel"))
            .accessibilityHint(Text("menu.reverseMouseWheel.hint"))
            Toggle(isOn: binding(\.smoothScrollingEnabled)) {
                Text("menu.smoothScrolling")
            }
            .accessibilityLabel(Text("menu.smoothScrolling"))
            .accessibilityHint(Text("menu.smoothScrolling.hint"))
            Toggle(isOn: binding(\.buttonMappingEnabled)) {
                Text("menu.buttonMapping")
            }
            .accessibilityLabel(Text("menu.buttonMapping"))
            .accessibilityHint(Text("menu.buttonMapping.hint"))
            if !appState.permissions.canProcessEvents {
                Button("menu.openPermissionGuide") {
                    showSettings(page: .permissions)
                }
                .accessibilityLabel(Text("menu.openPermissionGuide"))
                .accessibilityHint(Text("menu.openPermissionGuide.hint"))
            }
            Divider()
            Button("menu.openSettings") { showSettings() }
                .accessibilityLabel(Text("menu.openSettings"))
                .accessibilityHint(Text("menu.openSettings.hint"))
            Button("menu.permissionsDiagnostics") { showSettings(page: .permissions) }
                .accessibilityLabel(Text("menu.permissionsDiagnostics"))
                .accessibilityHint(Text("menu.permissionsDiagnostics.hint"))
            Button("menu.about") { showAbout() }
                .accessibilityLabel(Text("menu.about"))
                .accessibilityHint(Text("menu.about.hint"))
            Divider()
            Button("menu.quit") {
                appState.prepareForTermination()
                NSApplication.shared.terminate(nil)
            }
            .accessibilityLabel(Text("menu.quit"))
            .accessibilityHint(Text("menu.quit.hint"))
        }
        .onAppear { appState.bootstrap() }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.settings[keyPath: keyPath] },
            set: { value in appState.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private func showSettings(page: SettingsPage? = nil) {
        if let page {
            appState.requestSettingsPage(page)
        }
        openWindow(id: AppWindow.settings.rawValue)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func showAbout() {
        openWindow(id: AppWindow.about.rawValue)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
