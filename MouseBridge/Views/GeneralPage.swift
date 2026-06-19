import SwiftUI

struct GeneralPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("section.basic") {
                SettingsToggleRow(
                    titleKey: "general.masterEnabled",
                    subtitleKey: "general.masterEnabled.desc",
                    isOn: boolBinding(\.masterEnabled)
                )
                SettingsToggleRow(
                    titleKey: "general.launchAtLogin",
                    subtitleKey: "general.launchAtLogin.desc",
                    isOn: boolBinding(\.launchAtLogin)
                )
                HStack {
                    Text("general.launchAtLogin.status")
                    Spacer()
                    Text(LocalizedStringKey(appState.launchItemStatus.titleKey))
                        .foregroundStyle(.secondary)
                }
                SettingsToggleRow(
                    titleKey: "general.menuBarVisible",
                    subtitleKey: "general.menuBarVisible.desc",
                    isOn: boolBinding(\.menuBarVisible)
                )
                SettingsToggleRow(
                    titleKey: "general.showSettingsAtLaunch",
                    subtitleKey: "general.showSettingsAtLaunch.desc",
                    isOn: boolBinding(\.showSettingsAtLaunch)
                )
            }

            Section("section.language") {
                Picker("general.language", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text("general.language"))
                .accessibilityHint(Text("general.language.hint"))
            }

            Section("section.actions") {
                Button("general.restoreDefaults", role: .destructive) {
                    appState.resetSettings()
                }
                .accessibilityLabel(Text("general.restoreDefaults"))
                .accessibilityHint(Text("general.restoreDefaults.hint"))
            }
        }
        .formStyle(.grouped)
        .settingPagePadding()
        .navigationTitle("page.general")
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { appState.settings[keyPath: keyPath] }, set: { value in appState.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { appState.settings.language }, set: { value in appState.updateSettings { $0.language = value } })
    }
}
