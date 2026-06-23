import SwiftUI

struct ScrollDirectionPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let noticeKey = appState.featureAvailabilityNoticeKey {
                    FeatureAvailabilityNoticeBanner(messageKey: noticeKey)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("section.scrollDirection")
                            .font(.headline)
                        SettingsToggleRow(titleKey: "scroll.reverseMouseWheel", subtitleKey: "scroll.reverseMouseWheel.desc", isOn: boolBinding(\.reverseMouseWheelEnabled))
                        Divider()
                        SettingsToggleRow(titleKey: "scroll.reverseVertical", subtitleKey: "scroll.reverseVertical.desc", isOn: boolBinding(\.reverseVertical))
                        Divider()
                        SettingsToggleRow(titleKey: "scroll.reverseHorizontal", subtitleKey: "scroll.reverseHorizontal.desc", isOn: boolBinding(\.reverseHorizontal))
                        Divider()
                        SettingsToggleRow(titleKey: "scroll.physicalWheelOnly", subtitleKey: "scroll.physicalWheelOnly.desc", isOn: boolBinding(\.physicalWheelOnly))
                        Divider()
                        SettingsToggleRow(titleKey: "scroll.preserveTrackpad", subtitleKey: "scroll.preserveTrackpad.desc", isOn: boolBinding(\.preserveTrackpadDirection))
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("section.magicMouse")
                                .font(.headline)
                            Picker("scroll.magicMouse.strategy", selection: magicMouseStrategyBinding) {
                                ForEach(MagicMouseScrollStrategy.allCases) { strategy in
                                    Text(LocalizedStringKey(strategy.titleKey)).tag(strategy)
                                }
                            }
                            .accessibilityLabel(Text("scroll.magicMouse.strategy"))
                            .accessibilityHint(Text("scroll.magicMouse.strategy.hint"))
                            Text("scroll.magicMouse.note")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .settingPagePadding()
        }
        .navigationTitle("page.scrollDirection")
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { appState.settings[keyPath: keyPath] }, set: { value in appState.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private var magicMouseStrategyBinding: Binding<MagicMouseScrollStrategy> {
        Binding(
            get: { appState.settings.magicMouseScrollStrategy },
            set: { value in appState.updateSettings { $0.magicMouseScrollStrategy = value } }
        )
    }
}
