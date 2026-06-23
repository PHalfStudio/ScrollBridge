import AppKit
import SwiftUI

@main
struct MouseBridgeApp: App {
    @NSApplicationDelegateAdaptor(MouseBridgeAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appState: AppState
    private let statusItemController: StatusItemController

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        statusItemController = StatusItemController(appState: appState)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        let _ = statusItemController.configureSettingsWindowOpener {
            openWindow(id: AppWindow.settings.rawValue)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Window("window.settings", id: AppWindow.settings.rawValue) {
            AppBootstrapView {
                SettingsRootView()
                    .environmentObject(appState)
                    .environment(\.locale, appState.locale)
            }
            .environmentObject(appState)
            .frame(minWidth: 760, minHeight: 500)
        }
        .defaultSize(width: 820, height: 560)
    }
}

enum AppWindow: String {
    case settings
}

struct AppBootstrapView<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    var content: () -> Content

    var body: some View {
        content()
            .onAppear { appState.bootstrap() }
    }
}
