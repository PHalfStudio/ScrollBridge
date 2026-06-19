import AppKit
import SwiftUI

@main
struct MouseBridgeApp: App {
    @StateObject private var appState: AppState
    private let statusItemController: StatusItemController

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        statusItemController = StatusItemController(appState: appState)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
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

        Window("window.about", id: AppWindow.about.rawValue) {
            AppBootstrapView {
                AboutPage()
                    .environmentObject(appState)
                    .environment(\.locale, appState.locale)
                    .frame(width: 520, height: 460)
            }
            .environmentObject(appState)
        }
    }
}

enum AppWindow: String {
    case settings
    case about
}

struct AppBootstrapView<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    var content: () -> Content

    var body: some View {
        content()
            .onAppear { appState.bootstrap() }
    }
}
