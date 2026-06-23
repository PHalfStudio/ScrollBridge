import AppKit
import Combine
import Darwin
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var permissions: PermissionSummary = .unknown
    @Published private(set) var launchItemStatus: LaunchItemStatus = .unknown
    @Published private(set) var eventTapStatus: EventTapRuntimeStatus = .stopped
    @Published private(set) var eventTapPerformance: EventTapPerformanceSnapshot = .empty
    @Published private(set) var devices: [DeviceProfile] = []
    @Published private(set) var conflictingInputTools: [ConflictingInputTool] = []
    @Published private(set) var logs: [DiagnosticsLogEntry] = []
    @Published private(set) var lastEventSummary: InputEventSummary = .none
    @Published private(set) var lastMouseButtonNumber: Int?
    @Published private(set) var lastMouseButtonCapture: MouseButtonCaptureEvent?
    @Published private(set) var lastError: String = "—"
    @Published private(set) var lastErrorCode: String = "none"
    @Published private(set) var requestedSettingsPage: SettingsPage?
    @Published private(set) var hasRequestedInitialSettingsWindow = false
    @Published private(set) var updateStatus: UpdateCheckStatus = .notChecked

    private let persistence: SettingsPersistence
    private let permissionService = PermissionService()
    private let loginItemService = LoginItemService()
    private let hidDeviceService = HIDDeviceService()
    private let conflictDetectionService = ConflictDetectionService()
    private let eventTapService = EventTapService()
    private let updateChecker: UpdateChecker
    private var refreshTimer: Timer?
    private var updateCheckTimer: Timer?
    private var isUpdateCheckInFlight = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var didBootstrap = false
    private var mouseButtonCaptureSequence = 0

    init(
        persistence: SettingsPersistence = SettingsPersistence(),
        updateChecker: UpdateChecker = UpdateChecker()
    ) {
        self.persistence = persistence
        self.updateChecker = updateChecker
        self.settings = persistence.load()
        if let errorCode = persistence.lastLoadErrorCode {
            lastError = errorCode
            lastErrorCode = errorCode
        }
        configureCallbacks()
    }


    var locale: Locale {
        if let identifier = settings.language.localeIdentifier {
            return Locale(identifier: identifier)
        }
        return .autoupdatingCurrent
    }

    var menuStatusKey: String {
        if !settings.hasCompletedOnboarding { return "status.setupRequired" }
        if !settings.masterEnabled { return "status.paused" }
        if !permissions.canProcessEvents { return "status.missingPermissions" }
        return "status.enabled"
    }

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        configureWorkspaceObservers()
        refreshAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAll(lightweight: true) }
        }
        checkForUpdatesAtLaunch()
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdates(trigger: .automatic) }
        }
    }

    func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in self.updateSettings { settings in settings[keyPath: keyPath] = value } }
        )
    }

    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        var next = settings
        transform(&next)
        next.normalize()
        settings = next
        persistence.save(next)
        applyRuntimeConfiguration()
        syncLoginItemIfNeeded()
    }

    var shouldPresentOnboarding: Bool {
        !settings.hasCompletedOnboarding
    }

    var shouldOpenSettingsAtLaunch: Bool {
        settings.shouldOpenSettingsWindowAtLaunch
    }

    var shouldInsertMenuBarExtra: Bool {
        MenuBarInsertionPolicy.shouldInsert(
            settings: settings,
            hasRequestedInitialSettingsWindow: hasRequestedInitialSettingsWindow
        )
    }

    var featureAvailabilityNoticeKey: String? {
        FeatureAvailabilityNotice.messageKey(settings: settings, permissions: permissions)
    }

    func completeOnboarding() {
        updateSettings { settings in
            settings.hasCompletedOnboarding = true
        }
        addLog(level: "info", message: "diagnostics.log.onboardingCompleted")
    }

    func markInitialSettingsWindowRequestHandled() {
        hasRequestedInitialSettingsWindow = true
    }

    func resetSettings() {
        settings = persistence.reset()
        addLog(level: "info", message: "diagnostics.log.settingsReset")
        applyRuntimeConfiguration()
        syncLoginItemIfNeeded()
    }

    func prepareForTermination() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        eventTapService.stop()
        addLog(level: "info", message: "diagnostics.log.appWillTerminate")
    }

    func refreshAll(lightweight: Bool = false) {
        permissions = permissionService.refreshStatus()
        launchItemStatus = loginItemService.status()
        eventTapPerformance = eventTapService.performanceSnapshot()
        if !lightweight {
            refreshDevices()
            refreshConflicts()
        }
        applyRuntimeConfiguration()
    }

    func refreshDevices() {
        devices = hidDeviceService.snapshotDevices(overrides: settings.deviceOverrides)
    }

    func refreshConflicts() {
        conflictingInputTools = conflictDetectionService.snapshotConflicts()
    }

    func requestPermission(_ kind: PermissionKind) {
        switch kind {
        case .inputMonitoring:
            _ = permissionService.requestInputMonitoring()
        case .accessibility:
            _ = permissionService.requestAccessibility()
        }
        refreshAll()
    }

    func openPermissionSettings(_ kind: PermissionKind) {
        permissionService.openPrivacySettings(kind: kind)
    }

    func requestSettingsPage(_ page: SettingsPage) {
        requestedSettingsPage = page
    }

    func clearRequestedSettingsPage() {
        requestedSettingsPage = nil
    }

    func addExcludedBundleIdentifier(_ bundleIdentifier: String) {
        updateSettings { settings in
            settings.excludedBundleIdentifiers.append(bundleIdentifier)
        }
    }

    func removeExcludedBundleIdentifiers(at offsets: IndexSet) {
        updateSettings { settings in
            settings.excludedBundleIdentifiers.remove(atOffsets: offsets)
        }
    }

    func removeExcludedBundleIdentifier(_ bundleIdentifier: String) {
        updateSettings { settings in
            settings.excludedBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        }
    }

    func setDeviceOverride(deviceID: String, kind: InputDeviceKind) {
        updateSettings { settings in
            settings.deviceOverrides[deviceID] = kind
        }
        refreshDevices()
    }

    func addOrReplaceMapping(_ mapping: ButtonMapping) -> Bool {
        let engine = ButtonMappingEngine()
        guard engine.canInsert(mapping, into: settings.buttonMappings) else {
            lastError = String(localized: "mapping.duplicateMouseButton")
            lastErrorCode = "mapping_duplicate_mouse_button"
            addLog(level: "warning", message: "mapping.duplicateMouseButton")
            return false
        }
        updateSettings { settings in
            if let index = settings.buttonMappings.firstIndex(where: { $0.id == mapping.id }) {
                settings.buttonMappings[index] = mapping
            } else {
                settings.buttonMappings.append(mapping)
            }
        }
        return true
    }

    func deleteMappings(at offsets: IndexSet) {
        updateSettings { settings in
            settings.buttonMappings.remove(atOffsets: offsets)
        }
    }

    func removeMapping(_ mapping: ButtonMapping) {
        updateSettings { settings in
            settings.buttonMappings.removeAll { $0.id == mapping.id }
        }
    }

    func checkForUpdatesAtLaunch() {
        checkForUpdates(trigger: .automatic)
    }

    func checkForUpdatesManually() {
        checkForUpdates(trigger: .manual)
    }

    private func checkForUpdates(trigger: UpdateCheckTrigger) {
        guard !isUpdateCheckInFlight else { return }
        isUpdateCheckInFlight = true
        Task { @MainActor in
            defer { isUpdateCheckInFlight = false }
            let currentBuildNumber = Int(AppAboutMetadata.current.build) ?? 0
            let result = await updateChecker.check(
                currentBuildNumber: currentBuildNumber,
                trigger: trigger
            )
            switch result {
            case .updateAvailable(let release):
                updateStatus = .updateAvailable
                guard updateChecker.shouldPresentUpdatePrompt(trigger: trigger) else { return }
                presentUpdatePrompt(release)
            case .upToDate, .notModified:
                updateStatus = .latest
            case .unavailable, .skipped:
                break
            }
        }
    }

    private func presentUpdatePrompt(_ release: AvailableUpdate) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "updates.available.title")
        alert.informativeText = [
            String(format: String(localized: "updates.available.versionFormat"), release.name),
            release.body,
            String(localized: "updates.available.prompt")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
        alert.addButton(withTitle: String(localized: "updates.action.update"))
        alert.addButton(withTitle: String(localized: "updates.action.close"))
        alert.addButton(withTitle: String(localized: "updates.action.remindLater"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.htmlURL)
        case .alertThirdButtonReturn:
            updateChecker.suppressAutomaticPromptsForSevenDays()
        default:
            break
        }
    }

    func exportDiagnostics() -> URL? {
        let payload = DiagnosticsExport(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: ProcessInfo.processInfo.machineHardwareName,
            permissions: permissions,
            loginItemStatus: launchItemStatus,
            eventTapStatus: eventTapStatus,
            lastErrorCode: lastErrorCode,
            performance: eventTapService.performanceSnapshot(),
            devices: devices,
            conflictingInputTools: conflictingInputTools,
            settingsSummary: DiagnosticsSettingsSummary(settings: settings),
            recentLogs: logs
        )
        guard let data = try? JSONEncoder.pretty.encode(payload) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MouseBridge-Diagnostics-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            addLog(level: "info", message: "diagnostics.log.exported")
            return url
        } catch {
            lastError = error.localizedDescription
            lastErrorCode = "diagnostics_export_failed"
            addLog(level: "error", message: lastError)
            return nil
        }
    }

    private func configureCallbacks() {
        eventTapService.statusHandler = { [weak self] status, error in
            DispatchQueue.main.async {
                self?.eventTapStatus = status
                if let error {
                    self?.lastError = error
                    self?.lastErrorCode = status.diagnosticsErrorCode
                    self?.addLog(level: "error", message: error)
                }
            }
        }
        eventTapService.eventHandler = { [weak self] summary in
            DispatchQueue.main.async {
                self?.lastEventSummary = summary
                if let button = summary.argument {
                    self?.lastMouseButtonNumber = button
                    if let self {
                        self.mouseButtonCaptureSequence += 1
                        self.lastMouseButtonCapture = MouseButtonCaptureEvent(buttonNumber: button, sequence: self.mouseButtonCaptureSequence)
                    }
                }
            }
        }
    }

    private func configureWorkspaceObservers() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleSystemWillSleep() }
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleSystemDidWake() }
            }
        )
    }

    private func handleSystemWillSleep() {
        eventTapService.stop()
        addLog(level: "info", message: "diagnostics.log.systemWillSleep")
    }

    private func handleSystemDidWake() {
        addLog(level: "info", message: "diagnostics.log.systemDidWake")
        refreshAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            Task { @MainActor in self?.refreshAll() }
        }
    }

    private func applyRuntimeConfiguration() {
        guard settings.hasCompletedOnboarding else {
            eventTapService.updateConfig(.disabled)
            return
        }
        let snapshot = settings.runtimeSnapshot(permissions: permissions)
        if snapshot.shouldHandleEvents {
            do {
                try eventTapService.start(with: snapshot)
            } catch {
                lastError = error.localizedDescription
                lastErrorCode = "event_tap_start_failed"
                addLog(level: "error", message: error.localizedDescription)
            }
        } else {
            eventTapService.updateConfig(snapshot)
        }
    }

    private func syncLoginItemIfNeeded() {
        do {
            launchItemStatus = try loginItemService.setEnabled(settings.launchAtLogin)
        } catch {
            lastError = error.localizedDescription
            lastErrorCode = "login_item_update_failed"
            launchItemStatus = loginItemService.status()
            addLog(level: "error", message: error.localizedDescription)
        }
    }

    private func addLog(level: String, message: String) {
        logs.insert(DiagnosticsLogEntry(level: level, message: message), at: 0)
        if logs.count > 20 {
            logs.removeLast(logs.count - 20)
        }
    }
}

struct DiagnosticsExport: Codable {
    var appVersion: String
    var build: String
    var macOS: String
    var architecture: String
    var permissions: PermissionSummary
    var loginItemStatus: LaunchItemStatus
    var eventTapStatus: EventTapRuntimeStatus
    var lastErrorCode: String
    var performance: EventTapPerformanceSnapshot
    var devices: [DeviceProfile]
    var conflictingInputTools: [ConflictingInputTool]
    var settingsSummary: DiagnosticsSettingsSummary
    var recentLogs: [DiagnosticsLogEntry]
}

struct DiagnosticsSettingsSummary: Codable {
    var masterEnabled: Bool
    var reverseMouseWheelEnabled: Bool
    var magicMouseScrollStrategy: MagicMouseScrollStrategy
    var smoothScrollingEnabled: Bool
    var smoothSteps: Int
    var buttonMappingEnabled: Bool
    var hasCompletedOnboarding: Bool
    var language: AppLanguage
    var mappingCount: Int
    var deviceOverrideCount: Int
    var excludedAppCount: Int

    init(settings: AppSettings) {
        masterEnabled = settings.masterEnabled
        reverseMouseWheelEnabled = settings.reverseMouseWheelEnabled
        magicMouseScrollStrategy = settings.magicMouseScrollStrategy
        smoothScrollingEnabled = settings.smoothScrollingEnabled
        smoothSteps = settings.smoothSteps
        buttonMappingEnabled = settings.buttonMappingEnabled
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        language = settings.language
        mappingCount = settings.buttonMappings.count
        deviceOverrideCount = settings.deviceOverrides.count
        excludedAppCount = settings.excludedBundleIdentifiers.count
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return machine.withUnsafeBufferPointer { buffer in
            let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self)
        }
    }
}
