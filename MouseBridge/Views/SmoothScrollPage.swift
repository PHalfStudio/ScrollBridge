import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SmoothScrollPage: View {
    @EnvironmentObject private var appState: AppState
    @State private var newBundleIdentifier = ""
    @State private var appSelectionErrorKey: String?

    var body: some View {
        Form {
            if let noticeKey = appState.featureAvailabilityNoticeKey {
                Section {
                    FeatureAvailabilityNoticeBanner(messageKey: noticeKey)
                }
            }
            Section("section.smoothScroll") {
                SettingsToggleRow(titleKey: "smooth.enabled", subtitleKey: "smooth.enabled.desc", isOn: boolBinding(\.smoothScrollingEnabled))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("smooth.steps")
                        Spacer()
                        Text("\(appState.settings.smoothSteps)")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: smoothStepsBinding, in: 1...20, step: 1) {
                        Text("smooth.steps")
                    }
                    .accessibilityLabel(Text("smooth.steps"))
                    .accessibilityHint(Text("smooth.steps.hint"))
                    .accessibilityValue(Text("\(appState.settings.smoothSteps)"))
                    Text(smoothHintKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SettingsToggleRow(titleKey: "smooth.horizontal", subtitleKey: "smooth.horizontal.desc", isOn: boolBinding(\.smoothHorizontalEnabled))
                HStack {
                    Text("smooth.duration")
                    Slider(value: durationBinding, in: 40...240, step: 10)
                        .accessibilityLabel(Text("smooth.duration"))
                        .accessibilityHint(Text("smooth.duration.hint"))
                        .accessibilityValue(Text(smoothDurationValue))
                    Text(smoothDurationValue)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }
                Picker("smooth.curve", selection: curveBinding) {
                    ForEach(SmoothCurve.allCases) { curve in
                        Text(LocalizedStringKey(curve.titleKey)).tag(curve)
                    }
                }
                .accessibilityLabel(Text("smooth.curve"))
                .accessibilityHint(Text("smooth.curve.hint"))
                SettingsToggleRow(titleKey: "smooth.inertia", subtitleKey: "smooth.inertia.desc", isOn: boolBinding(\.smoothInertiaEnabled))
                HStack {
                    Text("smooth.speedMultiplier")
                    Slider(value: speedBinding, in: 0.5...2, step: 0.1)
                        .accessibilityLabel(Text("smooth.speedMultiplier"))
                        .accessibilityHint(Text("smooth.speedMultiplier.hint"))
                        .accessibilityValue(Text("\(appState.settings.smoothSpeedMultiplier)"))
                    Text(appState.settings.smoothSpeedMultiplier, format: .number.precision(.fractionLength(1)))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("section.excludedApps") {
                Text("excludedApps.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("excludedApps.placeholder", text: $newBundleIdentifier)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(Text("excludedApps.placeholder"))
                        .accessibilityHint(Text("excludedApps.placeholder.hint"))
                    Button("excludedApps.add") {
                        addExcludedBundleIdentifier()
                    }
                    .accessibilityLabel(Text("excludedApps.add"))
                    .accessibilityHint(Text("excludedApps.add.hint"))
                    .disabled(newBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button("excludedApps.chooseApp") {
                    chooseExcludedApplication()
                }
                .accessibilityLabel(Text("excludedApps.chooseApp"))
                .accessibilityHint(Text("excludedApps.chooseApp.hint"))

                if let appSelectionErrorKey {
                    Label(LocalizedStringKey(appSelectionErrorKey), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if appState.settings.excludedBundleIdentifiers.isEmpty {
                    Text("excludedApps.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.settings.excludedBundleIdentifiers, id: \.self) { bundleIdentifier in
                        HStack {
                            Text(bundleIdentifier)
                                .font(.system(.body, design: .monospaced))
                                .accessibilityLabel(Text(excludedAppAccessibilityLabel(for: bundleIdentifier)))
                                .accessibilityHint(Text("excludedApps.row.accessibilityHint"))
                            Spacer()
                            Button("excludedApps.delete", role: .destructive) {
                                appState.removeExcludedBundleIdentifier(bundleIdentifier)
                            }
                            .accessibilityLabel(Text("excludedApps.delete"))
                            .accessibilityHint(Text("excludedApps.delete.hint"))
                        }
                    }
                    .onDelete { offsets in
                        appState.removeExcludedBundleIdentifiers(at: offsets)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .settingPagePadding()
        .navigationTitle("page.smoothScroll")
    }

    private var smoothHintKey: LocalizedStringKey {
        if appState.settings.smoothSteps <= 3 { return "smooth.hint.direct" }
        if appState.settings.smoothSteps <= 10 { return "smooth.hint.balanced" }
        return "smooth.hint.soft"
    }

    private var smoothDurationValue: String {
        String(
            format: NSLocalizedString("smooth.duration.valueFormat", comment: ""),
            appState.settings.smoothDurationMilliseconds
        )
    }

    private func excludedAppAccessibilityLabel(for bundleIdentifier: String) -> String {
        String(
            format: NSLocalizedString("excludedApps.row.accessibilityLabelFormat", comment: ""),
            bundleIdentifier
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { appState.settings[keyPath: keyPath] }, set: { value in appState.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private var smoothStepsBinding: Binding<Double> {
        Binding(get: { Double(appState.settings.smoothSteps) }, set: { value in appState.updateSettings { $0.smoothSteps = Int(value.rounded()) } })
    }

    private var speedBinding: Binding<Double> {
        Binding(get: { appState.settings.smoothSpeedMultiplier }, set: { value in appState.updateSettings { $0.smoothSpeedMultiplier = value } })
    }

    private var durationBinding: Binding<Double> {
        Binding(get: { Double(appState.settings.smoothDurationMilliseconds) }, set: { value in appState.updateSettings { $0.smoothDurationMilliseconds = Int(value.rounded()) } })
    }

    private var curveBinding: Binding<SmoothCurve> {
        Binding(get: { appState.settings.smoothCurve }, set: { value in appState.updateSettings { $0.smoothCurve = value } })
    }

    private func addExcludedBundleIdentifier() {
        let trimmed = newBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.addExcludedBundleIdentifier(trimmed)
        newBundleIdentifier = ""
        appSelectionErrorKey = nil
    }

    private func chooseExcludedApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addExcludedApplication(at: url)
    }

    private func addExcludedApplication(at url: URL) {
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            appSelectionErrorKey = "excludedApps.chooseApp.invalid"
            return
        }
        appState.addExcludedBundleIdentifier(bundleIdentifier)
        appSelectionErrorKey = nil
    }
}
