import SwiftUI

struct PermissionsDiagnosticsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("permissions.title")
                            .font(.title3.weight(.semibold))
                        Text("permissions.privacyCopy")
                            .foregroundStyle(.secondary)
                        PermissionRow(kind: .inputMonitoring, state: appState.permissions.inputMonitoring)
                        PermissionRow(kind: .accessibility, state: appState.permissions.accessibility)
                        HStack {
                            Button("permissions.recheck") { appState.refreshAll() }
                                .accessibilityLabel(Text("permissions.recheck"))
                                .accessibilityHint(Text("permissions.recheck.hint"))
                            Button("permissions.openInputMonitoring") { appState.openPermissionSettings(.inputMonitoring) }
                                .accessibilityLabel(Text("permissions.openInputMonitoring"))
                                .accessibilityHint(Text("permissions.openInputMonitoring.hint"))
                            Button("permissions.openAccessibility") { appState.openPermissionSettings(.accessibility) }
                                .accessibilityLabel(Text("permissions.openAccessibility"))
                                .accessibilityHint(Text("permissions.openAccessibility.hint"))
                        }
                    }
                }

                Form {
                    Section("diagnostics.runtime") {
                        row("diagnostics.inputMonitoring", LocalizedStringKey(appState.permissions.inputMonitoring.titleKey))
                        row("diagnostics.accessibility", LocalizedStringKey(appState.permissions.accessibility.titleKey))
                        row("diagnostics.loginItem", LocalizedStringKey(appState.launchItemStatus.titleKey))
                        row("diagnostics.eventTap", LocalizedStringKey(appState.eventTapStatus.titleKey))
                        row("diagnostics.devices", "\(appState.devices.count)")
                        row("diagnostics.excludedApps", "\(appState.settings.excludedBundleIdentifiers.count)")
                        row("diagnostics.conflicts", "\(appState.conflictingInputTools.count)")
                        eventSummaryRow("diagnostics.lastEvent", appState.lastEventSummary)
                        diagnosticValueRow("diagnostics.lastError", DiagnosticDisplayValue(appState.lastError))
                        row("diagnostics.lastErrorCode", appState.lastErrorCode)
                        row("diagnostics.eventCount", "\(appState.eventTapPerformance.eventCount)")
                        row("diagnostics.averageCallback", localizedCallbackDuration(appState.eventTapPerformance.averageCallbackMilliseconds))
                        row("diagnostics.p95Callback", localizedCallbackDuration(appState.eventTapPerformance.p95CallbackMilliseconds))
                    }
                    Section("diagnostics.devices") {
                        if appState.devices.isEmpty {
                            Text("diagnostics.noDevices")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.devices) { device in
                                let summary = DeviceProfileDisplaySummary(device: device)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(device.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(LocalizedStringKey(device.kind.titleKey))
                                            .foregroundStyle(.secondary)
                                    }
                                    DeviceDetailGrid(summary: summary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    Section("diagnostics.conflicts") {
                        if appState.conflictingInputTools.isEmpty {
                            Text("diagnostics.noConflicts")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("diagnostics.conflicts.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(appState.conflictingInputTools) { tool in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tool.name)
                                    if let bundleIdentifier = tool.bundleIdentifier {
                                        Text(bundleIdentifier)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Section("permissions.reset.title") {
                        Text("permissions.reset.body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("diagnostics.logs") {
                        if appState.logs.isEmpty {
                            Text("diagnostics.noLogs")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.logs) { log in
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey(log.message))
                                    Text(log.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Section("diagnostics.export") {
                        Button("diagnostics.exportButton") { _ = appState.exportDiagnostics() }
                            .accessibilityLabel(Text("diagnostics.exportButton"))
                            .accessibilityHint(Text("diagnostics.exportButton.hint"))
                    }
                }
                .formStyle(.grouped)
            }
            .settingPagePadding()
        }
        .navigationTitle("page.permissions")
    }

    private func row(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack { Text(key); Spacer(); Text(value).foregroundStyle(.secondary) }
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("diagnostics.row.accessibilityHint"))
    }

    private func row(_ key: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack { Text(key); Spacer(); Text(value).foregroundStyle(.secondary) }
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("diagnostics.row.accessibilityHint"))
    }

    private func eventSummaryRow(_ key: LocalizedStringKey, _ summary: InputEventSummary) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(summary.localizedDisplay)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("diagnostics.row.accessibilityHint"))
    }

    private func localizedCallbackDuration(_ milliseconds: Double) -> String {
        let format = NSLocalizedString("diagnostics.callbackMillisecondsFormat", comment: "")
        return String(format: format, milliseconds)
    }

    @ViewBuilder
    private func diagnosticValueRow(_ key: LocalizedStringKey, _ value: DiagnosticDisplayValue) -> some View {
        HStack {
            Text(key)
            Spacer()
            if value.isLocalizationKey {
                Text(LocalizedStringKey(value.rawValue))
                    .foregroundStyle(.secondary)
            } else {
                Text(value.rawValue)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("diagnostics.row.accessibilityHint"))
    }
}

struct PermissionRow: View {
    @EnvironmentObject private var appState: AppState
    let kind: PermissionKind
    let state: PermissionState

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                StatusPill(
                    titleKey: LocalizedStringKey(state.titleKey),
                    systemImage: state == .authorized ? "checkmark.shield" : "exclamationmark.triangle",
                    tint: state == .authorized ? .green : .orange
                )
                if let hintKey = PermissionStateActionHint.messageKey(for: state) {
                    Text(LocalizedStringKey(hintKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(kind == .inputMonitoring ? "permissions.inputMonitoring.desc" : "permissions.accessibility.desc")
            Spacer()
            Button("permissions.request") { appState.requestPermission(kind) }
                .accessibilityLabel(Text(LocalizedStringKey(permissionActionLabelKey)))
                .accessibilityHint(Text(LocalizedStringKey(permissionActionHintKey)))
        }
    }

    private var permissionActionLabelKey: String {
        switch kind {
        case .inputMonitoring:
            "permissions.request.inputMonitoring"
        case .accessibility:
            "permissions.request.accessibility"
        }
    }

    private var permissionActionHintKey: String {
        switch kind {
        case .inputMonitoring:
            "permissions.request.inputMonitoring.hint"
        case .accessibility:
            "permissions.request.accessibility.hint"
        }
    }
}
