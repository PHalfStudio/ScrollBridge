import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class PermissionService {
    private var requestedOrOpenedSettings: Set<PermissionKind> = []

    func refreshStatus() -> PermissionSummary {
        PermissionSummary(
            inputMonitoring: PermissionStateResolver.state(
                isAuthorized: CGPreflightListenEventAccess(),
                hasRequestedOrOpenedSettings: requestedOrOpenedSettings.contains(.inputMonitoring)
            ),
            accessibility: PermissionStateResolver.state(
                isAuthorized: AXIsProcessTrusted(),
                hasRequestedOrOpenedSettings: requestedOrOpenedSettings.contains(.accessibility)
            )
        )
    }

    @discardableResult
    func requestInputMonitoring() -> Bool {
        requestedOrOpenedSettings.insert(.inputMonitoring)
        return CGRequestListenEventAccess()
    }

    @discardableResult
    func requestAccessibility() -> Bool {
        requestedOrOpenedSettings.insert(.accessibility)
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openPrivacySettings(kind: PermissionKind) {
        let anchor: String
        switch kind {
        case .inputMonitoring:
            anchor = "Privacy_ListenEvent"
        case .accessibility:
            anchor = "Privacy_Accessibility"
        }
        requestedOrOpenedSettings.insert(kind)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct PermissionStateResolver: Equatable, Sendable {
    static func state(isAuthorized: Bool?, hasRequestedOrOpenedSettings: Bool) -> PermissionState {
        guard let isAuthorized else { return .unknown }
        if isAuthorized { return .authorized }
        return hasRequestedOrOpenedSettings ? .requiresRestart : .denied
    }
}
