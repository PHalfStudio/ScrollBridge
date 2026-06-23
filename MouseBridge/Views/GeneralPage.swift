import SwiftUI

struct GeneralPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("section.basic")
                            .font(.headline)
                        SettingsToggleRow(
                            titleKey: "general.masterEnabled",
                            subtitleKey: "general.masterEnabled.desc",
                            isOn: boolBinding(\.masterEnabled)
                        )
                        Divider()
                        SettingsToggleRow(
                            titleKey: "general.launchAtLogin",
                            subtitleKey: "general.launchAtLogin.desc",
                            isOn: boolBinding(\.launchAtLogin)
                        )
                        Divider()
                        HStack {
                            Text("general.launchAtLogin.status")
                            Spacer()
                            Text(LocalizedStringKey(appState.launchItemStatus.titleKey))
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        SettingsToggleRow(
                            titleKey: "general.menuBarVisible",
                            subtitleKey: "general.menuBarVisible.desc",
                            isOn: boolBinding(\.menuBarVisible)
                        )
                        Divider()
                        SettingsToggleRow(
                            titleKey: "general.showSettingsAtLaunch",
                            subtitleKey: "general.showSettingsAtLaunch.desc",
                            isOn: boolBinding(\.showSettingsAtLaunch)
                        )
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("section.language")
                                .font(.headline)
                            Picker("general.language", selection: languageBinding) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(LocalizedStringKey(language.titleKey)).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel(Text("general.language"))
                            .accessibilityHint(Text("general.language.hint"))
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("section.actions")
                                .font(.headline)
                            Button("general.restoreDefaults", role: .destructive) {
                                appState.resetSettings()
                            }
                            .accessibilityLabel(Text("general.restoreDefaults"))
                            .accessibilityHint(Text("general.restoreDefaults.hint"))
                        }
                    }
                }
            }
            .settingPagePadding()
        }
        .navigationTitle("page.general")
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { appState.settings[keyPath: keyPath] }, set: { value in appState.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { appState.settings.language }, set: { value in appState.updateSettings { $0.language = value } })
    }
}
