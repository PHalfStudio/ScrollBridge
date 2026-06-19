import SwiftUI

struct WelcomeOnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            Image(systemName: symbolName)
                .font(.system(size: 58, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 10) {
                Text(titleKey)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(descriptionKey)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            if step == 2 {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        PermissionRow(kind: .inputMonitoring, state: appState.permissions.inputMonitoring)
                        PermissionRow(kind: .accessibility, state: appState.permissions.accessibility)
                        HStack {
                            Button("permissions.openInputMonitoring") { appState.openPermissionSettings(.inputMonitoring) }
                                .accessibilityLabel(Text("permissions.openInputMonitoring"))
                                .accessibilityHint(Text("permissions.openInputMonitoring.hint"))
                            Button("permissions.openAccessibility") { appState.openPermissionSettings(.accessibility) }
                                .accessibilityLabel(Text("permissions.openAccessibility"))
                                .accessibilityHint(Text("permissions.openAccessibility.hint"))
                            Button("permissions.recheck") { appState.refreshAll() }
                                .accessibilityLabel(Text("permissions.recheck"))
                                .accessibilityHint(Text("permissions.recheck.hint"))
                        }
                    }
                }
                .frame(maxWidth: 680)
            }

            Spacer()
            HStack {
                Button("onboarding.back") { step = max(0, step - 1) }
                    .accessibilityLabel(Text("onboarding.back"))
                    .accessibilityHint(Text("onboarding.back.hint"))
                    .disabled(step == 0)
                Spacer()
                if step < 3 {
                    Button("onboarding.next") { step += 1 }
                        .accessibilityLabel(Text("onboarding.next"))
                        .accessibilityHint(Text("onboarding.next.hint"))
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("onboarding.enterSettings") {
                        appState.completeOnboarding()
                    }
                    .accessibilityLabel(Text("onboarding.enterSettings"))
                    .accessibilityHint(Text("onboarding.enterSettings.hint"))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: 680)
            .padding(.bottom, 24)
        }
        .padding(28)
        .onAppear { appState.refreshAll() }
    }

    private var symbolName: String {
        switch step {
        case 0: "computermouse"
        case 1: "arrow.up.arrow.down.circle"
        case 2: "lock.shield"
        default: "checkmark.circle"
        }
    }

    private var titleKey: LocalizedStringKey {
        switch step {
        case 0: "onboarding.welcome.title"
        case 1: "onboarding.features.title"
        case 2: "onboarding.permissions.title"
        default: "onboarding.ready.title"
        }
    }

    private var descriptionKey: LocalizedStringKey {
        switch step {
        case 0: "onboarding.welcome.desc"
        case 1: "onboarding.features.desc"
        case 2: "onboarding.permissions.desc"
        default: "onboarding.ready.desc"
        }
    }
}
