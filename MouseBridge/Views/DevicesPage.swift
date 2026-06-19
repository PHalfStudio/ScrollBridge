import SwiftUI

struct DevicesPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("devices.description")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("devices.refresh") { appState.refreshDevices() }
                    .accessibilityLabel(Text("devices.refresh"))
                    .accessibilityHint(Text("devices.refresh.hint"))
            }

            List(appState.devices) { device in
                DeviceRow(device: device)
                    .environmentObject(appState)
            }
        }
        .settingPagePadding()
        .navigationTitle("page.devices")
        .onAppear { appState.refreshDevices() }
    }
}

struct DeviceRow: View {
    @EnvironmentObject private var appState: AppState
    let device: DeviceProfile

    var body: some View {
        let summary = DeviceProfileDisplaySummary(device: device)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    DeviceDetailGrid(summary: summary)
                }
                Spacer()
                Picker("devices.kind", selection: kindBinding) {
                    ForEach(InputDeviceKind.allCases) { kind in
                        Text(LocalizedStringKey(kind.titleKey)).tag(kind)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(Text("devices.kind"))
                .accessibilityHint(Text("devices.kind.hint"))
                .frame(width: 180)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(deviceAccessibilityLabel(for: device)))
        .accessibilityHint(Text("devices.row.accessibilityHint"))
    }

    private var kindBinding: Binding<InputDeviceKind> {
        Binding(
            get: { device.kind },
            set: { value in appState.setDeviceOverride(deviceID: device.id, kind: value) }
        )
    }

    private func deviceAccessibilityLabel(for device: DeviceProfile) -> String {
        let summary = DeviceProfileDisplaySummary(device: device)
        let format = NSLocalizedString("devices.row.accessibilityLabelFormat", comment: "")
        return String(
            format: format,
            device.name,
            NSLocalizedString(device.kind.titleKey, comment: ""),
            summary.identityLine,
            summary.usageLine,
            NSLocalizedString(summary.standardHIDKey, comment: ""),
            summary.confidenceLine,
            summary.lastEventLine
        )
    }
}

struct DeviceDetailGrid: View {
    let summary: DeviceProfileDisplaySummary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            detailRow("devices.identity", summary.identityLine)
            detailRow("devices.usage", summary.usageLine)
            detailRow("devices.standardHID", LocalizedStringKey(summary.standardHIDKey))
            detailRow("devices.confidence", summary.confidenceLine)
            if let confirmationKey = summary.confirmationKey {
                detailRow("devices.classificationNote", LocalizedStringKey(confirmationKey))
            }
            detailRow("devices.lastEvent", summary.lastEventLine)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func detailRow(_ titleKey: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(titleKey)
            Text(value)
                .monospacedDigit()
        }
    }

    private func detailRow(_ titleKey: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        GridRow {
            Text(titleKey)
            Text(value)
        }
    }
}
