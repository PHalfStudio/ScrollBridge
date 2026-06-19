import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable, Equatable {
    case general
    case scrollDirection
    case smoothScroll
    case buttonMapping
    case devices
    case permissions
    case about

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .general: "page.general"
        case .scrollDirection: "page.scrollDirection"
        case .smoothScroll: "page.smoothScroll"
        case .buttonMapping: "page.buttonMapping"
        case .devices: "page.devices"
        case .permissions: "page.permissions"
        case .about: "page.about"
        }
    }

    var accessibilityHintKey: LocalizedStringKey {
        switch self {
        case .general: "page.general.hint"
        case .scrollDirection: "page.scrollDirection.hint"
        case .smoothScroll: "page.smoothScroll.hint"
        case .buttonMapping: "page.buttonMapping.hint"
        case .devices: "page.devices.hint"
        case .permissions: "page.permissions.hint"
        case .about: "page.about.hint"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .scrollDirection: "arrow.up.arrow.down.circle"
        case .smoothScroll: "waveform.path"
        case .buttonMapping: "keyboard"
        case .devices: "computermouse"
        case .permissions: "lock.shield"
        case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SettingsPage? = .general

    var body: some View {
        if appState.shouldPresentOnboarding {
            WelcomeOnboardingView()
                .environmentObject(appState)
        } else {
            NavigationSplitView {
                List(SettingsPage.allCases, selection: $selection) { page in
                    Label(page.titleKey, systemImage: page.symbolName)
                        .tag(page)
                        .accessibilityLabel(Text(page.titleKey))
                        .accessibilityHint(Text(page.accessibilityHintKey))
                }
                .navigationTitle("app.name")
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            } detail: {
                Group {
                    switch selection ?? .general {
                    case .general:
                        GeneralPage()
                    case .scrollDirection:
                        ScrollDirectionPage()
                    case .smoothScroll:
                        SmoothScrollPage()
                    case .buttonMapping:
                        ButtonMappingPage()
                    case .devices:
                        DevicesPage()
                    case .permissions:
                        PermissionsDiagnosticsPage()
                    case .about:
                        AboutPage(toolbarSafeAreaTopPadding: 72)
                    }
                }
                .environmentObject(appState)
            }
            .onAppear(perform: applyRequestedPage)
            .onChange(of: appState.requestedSettingsPage) { _, _ in
                applyRequestedPage()
            }
        }
    }

    private func applyRequestedPage() {
        guard let page = appState.requestedSettingsPage else { return }
        selection = page
        appState.clearRequestedSettingsPage()
    }
}
