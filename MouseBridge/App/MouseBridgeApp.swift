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
            .settingsWindowToolbarChrome()
            .background(SettingsWindowChromeApplier(language: appState.settings.language))
        }
        .defaultSize(width: 820, height: 560)
        .windowToolbarStyle(.unified(showsTitle: true))
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

private extension View {
    func settingsWindowToolbarChrome() -> some View {
        self
            // 不要再 hidden。让 macOS 26 自己决定 toolbar/titlebar 背景。
            .toolbarBackgroundVisibility(.automatic, for: .windowToolbar)
    }
}

private struct SettingsWindowChromeApplier: NSViewRepresentable {
    let language: AppLanguage

    func makeNSView(context: Context) -> WindowChromeView {
        let view = WindowChromeView()
        view.language = language
        return view
    }

    func updateNSView(_ nsView: WindowChromeView, context: Context) {
        nsView.language = language
        nsView.apply()
    }

    final class WindowChromeView: NSView {
        var language: AppLanguage = .system

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }

                Self.configure(window, language: language)

                DispatchQueue.main.async {
                    Self.configure(window, language: self.language)
                }
            }
        }

        private static func configure(_ window: NSWindow, language: AppLanguage) {
            window.title = AppLocalization.string("window.settings", language: language)
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.insert(.resizable)
            window.styleMask.remove(.fullScreen)
            window.collectionBehavior.insert(.fullScreenNone)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.collectionBehavior.remove(.fullScreenAuxiliary)

            window.standardWindowButton(.zoomButton)?.isEnabled = false

            // 不要强制透明，否则 titlebar 自己完全不画背景。
            // 背景、模糊、渐变交给系统 toolbar + scroll edge effect。
            window.titlebarAppearsTransparent = false

            // 去掉底部横线。不要再用 NSToolbar.showsBaselineSeparator。
            window.titlebarSeparatorStyle = .none

            // 统一 titlebar / toolbar 样式。
            window.toolbarStyle = .unified
        }
    }
}
