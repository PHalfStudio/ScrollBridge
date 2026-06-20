import Foundation
import CoreGraphics

public struct AppAboutMetadata: Equatable, Sendable {
    var version: String
    var build: String
    var gitCommit: String
    var copyright: String
    let licenseFileName = "LICENSES.md"
    let privacyFileName = "PRIVACY.md"
    let referenceProjectNames = [
        "Mac Mouse Fix",
        "Scroll Reverser",
        "Mos",
        "LinearMouse",
        "Karabiner-Elements"
    ]

    init(infoDictionary: [String: Any]) {
        self.version = infoDictionary["CFBundleShortVersionString"] as? String ?? "1.0"
        self.build = infoDictionary["CFBundleVersion"] as? String ?? "1"
        self.gitCommit = infoDictionary["ScrollBridgeGitCommit"] as? String ?? "unknown"
        self.copyright = infoDictionary["NSHumanReadableCopyright"] as? String ?? "© 2026 phalfstudio"
    }

    static var current: AppAboutMetadata {
        AppAboutMetadata(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    var versionDisplay: String {
        "\(version) (\(build))"
    }
}

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans
    case en

    public var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .zhHans: "zh-Hans"
        case .en: "en"
        }
    }

    var titleKey: String {
        switch self {
        case .system: "language.system"
        case .zhHans: "language.zhHans"
        case .en: "language.en"
        }
    }
}

public enum InputDeviceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mouse
    case trackpad
    case magicMouse
    case keyboard
    case ignored
    case unknown

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .mouse: "device.kind.mouse"
        case .trackpad: "device.kind.trackpad"
        case .magicMouse: "device.kind.magicMouse"
        case .keyboard: "device.kind.keyboard"
        case .ignored: "device.kind.ignored"
        case .unknown: "device.kind.unknown"
        }
    }
}

public enum MagicMouseScrollStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case preserve
    case reverseLikeMouse

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .preserve: "scroll.magicMouse.strategy.preserve"
        case .reverseLikeMouse: "scroll.magicMouse.strategy.reverseLikeMouse"
        }
    }
}

public enum EventTapRuntimeStatus: String, Codable, Sendable {
    case stopped
    case running
    case missingPermissions
    case disabledByTimeout
    case disabledByUserInput
    case failed

    var titleKey: String {
        switch self {
        case .stopped: "eventTap.stopped"
        case .running: "eventTap.running"
        case .missingPermissions: "eventTap.missingPermissions"
        case .disabledByTimeout: "eventTap.disabledByTimeout"
        case .disabledByUserInput: "eventTap.disabledByUserInput"
        case .failed: "eventTap.failed"
        }
    }

    var diagnosticsErrorCode: String {
        switch self {
        case .stopped: "event_tap_stopped"
        case .running: "none"
        case .missingPermissions: "event_tap_missing_permissions"
        case .disabledByTimeout: "event_tap_disabled_by_timeout"
        case .disabledByUserInput: "event_tap_disabled_by_user_input"
        case .failed: "event_tap_failed"
        }
    }
}

public enum PermissionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case inputMonitoring
    case accessibility

    public var id: String { rawValue }
}

public enum PermissionState: String, Codable, Sendable {
    case authorized
    case denied
    case requiresRestart
    case unknown

    var titleKey: String {
        switch self {
        case .authorized: "permission.authorized"
        case .denied: "permission.denied"
        case .requiresRestart: "permission.requiresRestart"
        case .unknown: "permission.unknown"
        }
    }
}

public struct PermissionSummary: Codable, Equatable, Sendable {
    var inputMonitoring: PermissionState
    var accessibility: PermissionState

    static let unknown = PermissionSummary(inputMonitoring: .unknown, accessibility: .unknown)

    var canProcessEvents: Bool {
        inputMonitoring == .authorized && accessibility == .authorized
    }
}

public struct FeatureAvailabilityNotice: Equatable, Sendable {
    static func messageKey(settings: AppSettings, permissions: PermissionSummary) -> String? {
        if !settings.hasCompletedOnboarding {
            return "feature.notice.setupRequired"
        }
        if !settings.masterEnabled {
            return "feature.notice.paused"
        }
        if !permissions.canProcessEvents {
            return "feature.notice.missingPermissions"
        }
        return nil
    }
}

public struct MenuBarInsertionPolicy: Equatable, Sendable {
    static func shouldInsert(settings: AppSettings, hasRequestedInitialSettingsWindow: Bool) -> Bool {
        if settings.shouldShowMenuBarExtra {
            return true
        }
        return settings.shouldOpenSettingsWindowAtLaunch && !hasRequestedInitialSettingsWindow
    }
}

public struct PermissionResetInstructions: Equatable, Sendable {
    var titleKey: String
    var bodyKey: String
    var affectedPermissionKinds: [PermissionKind]

    static let `default` = PermissionResetInstructions(
        titleKey: "permissions.reset.title",
        bodyKey: "permissions.reset.body",
        affectedPermissionKinds: [.inputMonitoring, .accessibility]
    )
}

public struct PermissionStateActionHint: Equatable, Sendable {
    static func messageKey(for state: PermissionState) -> String? {
        switch state {
        case .authorized:
            return nil
        case .denied:
            return "permissions.actionHint.denied"
        case .requiresRestart:
            return "permissions.actionHint.requiresRestart"
        case .unknown:
            return "permissions.actionHint.unknown"
        }
    }
}

public enum LaunchItemStatus: String, Codable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
    case unknown

    var titleKey: String {
        switch self {
        case .enabled: "login.enabled"
        case .disabled: "login.disabled"
        case .requiresApproval: "login.requiresApproval"
        case .unavailable: "login.unavailable"
        case .unknown: "login.unknown"
        }
    }
}

public enum SmoothCurve: String, Codable, CaseIterable, Identifiable, Sendable {
    case linear
    case easeOut

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .linear: "smooth.curve.linear"
        case .easeOut: "smooth.curve.easeOut"
        }
    }
}

public struct KeyboardShortcutDefinition: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String { "\(keyCode)-\(modifiersRawValue)" }
    var keyCode: UInt16
    var modifiersRawValue: UInt64
    var displayName: String

    init(keyCode: UInt16, modifiersRawValue: UInt64, displayName: String? = nil) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiersRawValue
        self.displayName = displayName ?? Self.makeDisplayName(keyCode: keyCode, modifiersRawValue: modifiersRawValue)
    }

    static func makeDisplayName(keyCode: UInt16, modifiersRawValue: UInt64) -> String {
        let flags = CGEventFlags(rawValue: modifiersRawValue)
        var parts: [String] = []
        if flags.contains(.maskCommand) { parts.append("⌘") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
            22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫",
            53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
            106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
            117: "⌦", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }

    static func supportsKeyCode(_ keyCode: UInt16) -> Bool {
        keyName(for: keyCode).hasPrefix("Key ") == false
    }
}

public struct MacOSPresetShortcut: Equatable, Identifiable, Sendable {
    public var id: String
    var titleKey: String
    var descriptionKey: String
    var shortcut: KeyboardShortcutDefinition

    static let allCases: [MacOSPresetShortcut] = [
        MacOSPresetShortcut(
            id: "spotlight",
            titleKey: "mapping.preset.spotlight",
            descriptionKey: "mapping.preset.spotlight.desc",
            shortcut: KeyboardShortcutDefinition(keyCode: 49, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        ),
        MacOSPresetShortcut(
            id: "appSwitcher",
            titleKey: "mapping.preset.appSwitcher",
            descriptionKey: "mapping.preset.appSwitcher.desc",
            shortcut: KeyboardShortcutDefinition(keyCode: 48, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        ),
        MacOSPresetShortcut(
            id: "hideApp",
            titleKey: "mapping.preset.hideApp",
            descriptionKey: "mapping.preset.hideApp.desc",
            shortcut: KeyboardShortcutDefinition(keyCode: 4, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        ),
        MacOSPresetShortcut(
            id: "minimizeWindow",
            titleKey: "mapping.preset.minimizeWindow",
            descriptionKey: "mapping.preset.minimizeWindow.desc",
            shortcut: KeyboardShortcutDefinition(keyCode: 46, modifiersRawValue: CGEventFlags.maskCommand.rawValue)
        ),
        MacOSPresetShortcut(
            id: "screenshotSelection",
            titleKey: "mapping.preset.screenshotSelection",
            descriptionKey: "mapping.preset.screenshotSelection.desc",
            shortcut: KeyboardShortcutDefinition(
                keyCode: 21,
                modifiersRawValue: CGEventFlags([.maskCommand, .maskShift]).rawValue
            )
        )
    ]

    static func preset(id: String) -> MacOSPresetShortcut? {
        allCases.first { $0.id == id }
    }

    static func preset(matching shortcut: KeyboardShortcutDefinition) -> MacOSPresetShortcut? {
        allCases.first {
            $0.shortcut.keyCode == shortcut.keyCode && $0.shortcut.modifiersRawValue == shortcut.modifiersRawValue
        }
    }
}

public enum SystemMappingAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case missionControl
    case currentAppWindows
    case spaceLeft
    case spaceRight
    case showDesktop

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .missionControl: "mapping.systemAction.missionControl"
        case .currentAppWindows: "mapping.systemAction.currentAppWindows"
        case .spaceLeft: "mapping.systemAction.spaceLeft"
        case .spaceRight: "mapping.systemAction.spaceRight"
        case .showDesktop: "mapping.systemAction.showDesktop"
        }
    }

    var descriptionKey: String {
        switch self {
        case .missionControl: "mapping.systemAction.missionControl.desc"
        case .currentAppWindows: "mapping.systemAction.currentAppWindows.desc"
        case .spaceLeft: "mapping.systemAction.spaceLeft.desc"
        case .spaceRight: "mapping.systemAction.spaceRight.desc"
        case .showDesktop: "mapping.systemAction.showDesktop.desc"
        }
    }

    var displayName: String {
        String(localized: String.LocalizationValue(titleKey))
    }

    var fallbackShortcut: KeyboardShortcutDefinition? {
        switch self {
        case .spaceLeft:
            KeyboardShortcutDefinition(keyCode: 123, modifiersRawValue: CGEventFlags.maskControl.rawValue)
        case .spaceRight:
            KeyboardShortcutDefinition(keyCode: 124, modifiersRawValue: CGEventFlags.maskControl.rawValue)
        case .showDesktop:
            KeyboardShortcutDefinition(keyCode: 4, modifiersRawValue: CGEventFlags.maskSecondaryFn.rawValue)
        case .missionControl, .currentAppWindows:
            nil
        }
    }
}

public struct MacOSSystemActionPreset: Equatable, Identifiable, Sendable {
    public var id: String { action.rawValue }
    var action: SystemMappingAction
    var titleKey: String { action.titleKey }
    var descriptionKey: String { action.descriptionKey }

    static let allCases: [MacOSSystemActionPreset] = [
        MacOSSystemActionPreset(action: .missionControl),
        MacOSSystemActionPreset(action: .currentAppWindows),
        MacOSSystemActionPreset(action: .spaceLeft),
        MacOSSystemActionPreset(action: .spaceRight),
        MacOSSystemActionPreset(action: .showDesktop)
    ]

    static func preset(id: String) -> MacOSSystemActionPreset? {
        allCases.first { $0.id == id }
    }
}

public enum ButtonMappingAction: Codable, Equatable, Hashable, Sendable {
    case keyboardShortcut(KeyboardShortcutDefinition)
    case systemAction(SystemMappingAction)

    private enum CodingKeys: String, CodingKey {
        case kind
        case shortcut
        case systemAction
    }

    private enum Kind: String, Codable {
        case keyboardShortcut
        case systemAction
    }

    var keyboardShortcut: KeyboardShortcutDefinition? {
        switch self {
        case .keyboardShortcut(let shortcut): shortcut
        case .systemAction: nil
        }
    }

    var systemAction: SystemMappingAction? {
        switch self {
        case .keyboardShortcut: nil
        case .systemAction(let action): action
        }
    }

    var displayName: String {
        switch self {
        case .keyboardShortcut(let shortcut):
            shortcut.displayName
        case .systemAction(let action):
            action.displayName
        }
    }

    var isValid: Bool {
        switch self {
        case .keyboardShortcut(let shortcut):
            KeyboardShortcutDefinition.supportsKeyCode(shortcut.keyCode)
        case .systemAction:
            true
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .keyboardShortcut
        switch kind {
        case .keyboardShortcut:
            self = .keyboardShortcut(try container.decode(KeyboardShortcutDefinition.self, forKey: .shortcut))
        case .systemAction:
            self = .systemAction(try container.decode(SystemMappingAction.self, forKey: .systemAction))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .keyboardShortcut(let shortcut):
            try container.encode(Kind.keyboardShortcut, forKey: .kind)
            try container.encode(shortcut, forKey: .shortcut)
        case .systemAction(let action):
            try container.encode(Kind.systemAction, forKey: .kind)
            try container.encode(action, forKey: .systemAction)
        }
    }
}

public enum ShortcutCaptureDecision: Equatable, Sendable {
    case capture(KeyboardShortcutDefinition)
    case cancel
    case clear
    case invalid
}

public enum ShortcutRecorderMode: String, CaseIterable, Identifiable, Sendable {
    case singleChord
    case separateKeys

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .singleChord: "mapping.editor.shortcut.mode.singleChord"
        case .separateKeys: "mapping.editor.shortcut.mode.separateKeys"
        }
    }

    var hintKey: String {
        switch self {
        case .singleChord: "mapping.editor.shortcut.hint"
        case .separateKeys: "mapping.editor.shortcut.separateHint"
        }
    }
}

public struct ShortcutCaptureInterpreter: Sendable {
    func interpret(keyCode: UInt16, modifiersRawValue: UInt64) -> ShortcutCaptureDecision {
        switch keyCode {
        case 53:
            return .cancel
        case 51, 117:
            return .clear
        default:
            guard KeyboardShortcutDefinition.supportsKeyCode(keyCode) else {
                return .invalid
            }
            return .capture(
                KeyboardShortcutDefinition(
                    keyCode: keyCode,
                    modifiersRawValue: modifiersRawValue
                )
            )
        }
    }

    static func modifierFlag(for keyCode: UInt16) -> UInt64? {
        switch keyCode {
        case 55, 54:
            CGEventFlags.maskCommand.rawValue
        case 58, 61:
            CGEventFlags.maskAlternate.rawValue
        case 59, 62:
            CGEventFlags.maskControl.rawValue
        case 56, 60:
            CGEventFlags.maskShift.rawValue
        default:
            nil
        }
    }
}

public struct ShortcutAssemblyKey: Equatable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case modifier
        case key
    }

    var kind: Kind
    var keyCode: UInt16
    var flagRawValue: UInt64

    static func modifier(keyCode: UInt16, flagRawValue: UInt64) -> ShortcutAssemblyKey {
        ShortcutAssemblyKey(kind: .modifier, keyCode: keyCode, flagRawValue: flagRawValue)
    }

    static func key(keyCode: UInt16) -> ShortcutAssemblyKey {
        ShortcutAssemblyKey(kind: .key, keyCode: keyCode, flagRawValue: 0)
    }

    var displayName: String {
        switch kind {
        case .modifier:
            KeyboardShortcutDefinition.makeDisplayName(keyCode: keyCode, modifiersRawValue: flagRawValue)
                .replacingOccurrences(of: KeyboardShortcutDefinition.keyName(for: keyCode), with: "")
        case .key:
            KeyboardShortcutDefinition.keyName(for: keyCode)
        }
    }
}

public enum ShortcutAssemblyAppendResult: Equatable, Sendable {
    case inProgress
    case complete(KeyboardShortcutDefinition)
    case duplicate
    case full
    case invalid
}

public struct ShortcutKeyAssemblySession: Equatable, Sendable {
    static let maximumKeyCount = 3

    private(set) var keys: [ShortcutAssemblyKey] = []

    init(keys: [ShortcutAssemblyKey] = []) {
        self.keys = Array(keys.prefix(Self.maximumKeyCount))
    }

    var displayName: String {
        keys.map(\.displayName).joined(separator: " + ")
    }

    var shortcut: KeyboardShortcutDefinition? {
        let modifierFlags = keys
            .filter { $0.kind == .modifier }
            .reduce(UInt64(0)) { $0 | $1.flagRawValue }
        let mainKeys = keys.filter { $0.kind == .key }
        guard mainKeys.count == 1, let mainKey = mainKeys.first else { return nil }
        return KeyboardShortcutDefinition(keyCode: mainKey.keyCode, modifiersRawValue: modifierFlags)
    }

    mutating func append(_ key: ShortcutAssemblyKey) -> ShortcutAssemblyAppendResult {
        guard keys.count < Self.maximumKeyCount else { return .full }
        switch key.kind {
        case .modifier:
            guard ShortcutCaptureInterpreter.modifierFlag(for: key.keyCode) == key.flagRawValue else {
                return .invalid
            }
            guard keys.contains(where: { $0.kind == .modifier && $0.flagRawValue == key.flagRawValue }) == false else {
                return .duplicate
            }
        case .key:
            guard KeyboardShortcutDefinition.supportsKeyCode(key.keyCode),
                  ShortcutCaptureInterpreter.modifierFlag(for: key.keyCode) == nil,
                  keys.contains(where: { $0.kind == .key }) == false else {
                return .invalid
            }
        }
        keys.append(key)
        if let shortcut {
            return .complete(shortcut)
        }
        return .inProgress
    }

    mutating func clear() {
        keys = []
    }
}

public struct MouseButtonCaptureEvent: Equatable, Sendable {
    var buttonNumber: Int
    var sequence: Int
}

public struct MouseButtonRecordingSession: Equatable, Sendable {
    static let defaultTimeout: TimeInterval = 15

    var startedAt: Date
    var initialEventSequence: Int?
    var timeout: TimeInterval

    init(startedAt: Date, initialEventSequence: Int?, timeout: TimeInterval = Self.defaultTimeout) {
        self.startedAt = startedAt
        self.initialEventSequence = initialEventSequence
        self.timeout = timeout
    }

    func isActive(at date: Date) -> Bool {
        date.timeIntervalSince(startedAt) < timeout
    }

    func capturedButton(from event: MouseButtonCaptureEvent?, at date: Date) -> Int? {
        guard isActive(at: date), let event else { return nil }
        guard event.sequence != initialEventSequence else { return nil }
        guard event.buttonNumber >= 3 else { return nil }
        return event.buttonNumber
    }
}

public struct ShortcutRecordingSession: Equatable, Sendable {
    static let defaultTimeout: TimeInterval = 15

    var startedAt: Date
    var timeout: TimeInterval

    init(startedAt: Date, timeout: TimeInterval = Self.defaultTimeout) {
        self.startedAt = startedAt
        self.timeout = timeout
    }

    func isActive(at date: Date) -> Bool {
        date.timeIntervalSince(startedAt) < timeout
    }

    func restarted(at date: Date) -> ShortcutRecordingSession {
        ShortcutRecordingSession(startedAt: date, timeout: timeout)
    }

    func cancelled(at date: Date) -> ShortcutRecordingSession {
        ShortcutRecordingSession(startedAt: date.addingTimeInterval(-timeout), timeout: timeout)
    }
}

public struct ButtonMapping: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    var isEnabled: Bool
    var name: String
    var mouseButtonNumber: Int
    var action: ButtonMappingAction
    var scope: String
    var note: String

    var shortcut: KeyboardShortcutDefinition {
        get {
            action.keyboardShortcut ?? KeyboardShortcutDefinition(keyCode: 0, modifiersRawValue: 0, displayName: action.displayName)
        }
        set {
            action = .keyboardShortcut(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "",
        mouseButtonNumber: Int,
        shortcut: KeyboardShortcutDefinition,
        scope: String = "global",
        note: String = ""
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mouseButtonNumber = mouseButtonNumber
        self.action = .keyboardShortcut(shortcut)
        self.scope = scope
        self.note = note
    }

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "",
        mouseButtonNumber: Int,
        action: ButtonMappingAction,
        scope: String = "global",
        note: String = ""
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mouseButtonNumber = mouseButtonNumber
        self.action = action
        self.scope = scope
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id
        case isEnabled
        case name
        case mouseButtonNumber
        case action
        case shortcut
        case scope
        case note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        name = (try container.decodeIfPresent(String.self, forKey: .name) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        mouseButtonNumber = try container.decode(Int.self, forKey: .mouseButtonNumber)
        if let decodedAction = try container.decodeIfPresent(ButtonMappingAction.self, forKey: .action) {
            action = decodedAction
        } else {
            action = .keyboardShortcut(try container.decode(KeyboardShortcutDefinition.self, forKey: .shortcut))
        }
        scope = try container.decodeIfPresent(String.self, forKey: .scope) ?? "global"
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(name, forKey: .name)
        try container.encode(mouseButtonNumber, forKey: .mouseButtonNumber)
        try container.encode(action, forKey: .action)
        if let shortcut = action.keyboardShortcut {
            try container.encode(shortcut, forKey: .shortcut)
        }
        try container.encode(scope, forKey: .scope)
        try container.encode(note, forKey: .note)
    }
}

public struct ButtonMappingListSummary: Equatable, Sendable {
    var name: String?
    var actionDisplayName: String
    var scopeKey: String
    var note: String

    init(mapping: ButtonMapping) {
        let trimmedName = mapping.name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmedName.isEmpty ? nil : trimmedName
        actionDisplayName = mapping.action.displayName
        scopeKey = mapping.scope == "global" ? "mapping.scope.global" : "mapping.scope.custom"
        let trimmedNote = mapping.note.trimmingCharacters(in: .whitespacesAndNewlines)
        note = trimmedNote.isEmpty ? "—" : trimmedNote
    }
}

public struct ButtonMappingRiskWarning: Equatable, Sendable {
    static func messageKey(for mouseButtonNumber: Int) -> String? {
        mouseButtonNumber == 3 ? "mapping.editor.middleButtonRisk" : nil
    }
}

public struct ButtonMappingEditorDraft: Equatable, Sendable {
    var mouseButtonNumber: Int
    var action: ButtonMappingAction?

    static let newMapping = ButtonMappingEditorDraft(mouseButtonNumber: 0, action: nil)

    init(mouseButtonNumber: Int, action: ButtonMappingAction?) {
        self.mouseButtonNumber = mouseButtonNumber
        self.action = action
    }

    init(mouseButtonNumber: Int, shortcut: KeyboardShortcutDefinition?) {
        self.mouseButtonNumber = mouseButtonNumber
        action = shortcut.map { .keyboardShortcut($0) }
    }

    var shortcut: KeyboardShortcutDefinition? {
        action?.keyboardShortcut
    }

    var canRecordShortcut: Bool {
        mouseButtonNumber >= 3
    }

    func shouldRestartShortcutRecording(afterChangingMouseButtonTo newMouseButtonNumber: Int) -> Bool {
        !canRecordShortcut && newMouseButtonNumber >= 3
    }

    func canSave(conflictMessageKey: String?) -> Bool {
        canRecordShortcut && action?.isValid == true && conflictMessageKey == nil
    }
}

public struct DeviceProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    var name: String
    var vendorID: Int?
    var productID: Int?
    var transport: String
    var usagePage: Int?
    var usage: Int?
    var isStandardHID: Bool
    var kind: InputDeviceKind
    var confidence: Double
    var lastEventDescription: String?

    init(
        id: String,
        name: String,
        vendorID: Int? = nil,
        productID: Int? = nil,
        transport: String = "",
        usagePage: Int? = nil,
        usage: Int? = nil,
        isStandardHID: Bool = false,
        kind: InputDeviceKind = .unknown,
        confidence: Double = 0,
        lastEventDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
        self.usagePage = usagePage
        self.usage = usage
        self.isStandardHID = isStandardHID
        self.kind = kind
        self.confidence = confidence
        self.lastEventDescription = lastEventDescription
    }
}

public struct DeviceProfileDisplaySummary: Equatable, Sendable {
    var identityLine: String
    var usageLine: String
    var standardHIDKey: String
    var confidenceLine: String
    var lastEventLine: String
    var confirmationKey: String?

    init(device: DeviceProfile) {
        identityLine = [
            device.vendorID.map(String.init) ?? "—",
            device.productID.map(String.init) ?? "—",
            device.transport.isEmpty ? "HID" : device.transport
        ].joined(separator: " · ")
        usageLine = [
            device.usagePage.map(String.init) ?? "—",
            device.usage.map(String.init) ?? "—"
        ].joined(separator: " · ")
        standardHIDKey = device.isStandardHID ? "devices.standardHID.yes" : "devices.standardHID.no"
        confidenceLine = "\(Int((device.confidence * 100).rounded()))%"
        lastEventLine = device.lastEventDescription ?? "—"
        confirmationKey = device.confidence < 0.65 ? "devices.classificationNeedsConfirmation" : nil
    }
}

public struct DeviceOverride: Codable, Equatable, Sendable {
    var deviceID: String
    var kind: InputDeviceKind
}

public struct ConflictingInputTool: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    var name: String
    var bundleIdentifier: String?

    init(id: String, name: String, bundleIdentifier: String?) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var masterEnabled: Bool
    var reverseMouseWheelEnabled: Bool
    var reverseVertical: Bool
    var reverseHorizontal: Bool
    var physicalWheelOnly: Bool
    var preserveTrackpadDirection: Bool
    var magicMouseScrollStrategy: MagicMouseScrollStrategy
    var smoothScrollingEnabled: Bool
    var smoothSteps: Int
    var smoothDurationMilliseconds: Int
    var smoothCurve: SmoothCurve
    var smoothSpeedMultiplier: Double
    var smoothHorizontalEnabled: Bool
    var smoothInertiaEnabled: Bool
    var buttonMappingEnabled: Bool
    var hasCompletedOnboarding: Bool
    var launchAtLogin: Bool
    var language: AppLanguage
    var menuBarVisible: Bool
    var showSettingsAtLaunch: Bool
    var excludedBundleIdentifiers: [String]
    var deviceOverrides: [String: InputDeviceKind]
    var buttonMappings: [ButtonMapping]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        masterEnabled: Bool = true,
        reverseMouseWheelEnabled: Bool = true,
        reverseVertical: Bool = true,
        reverseHorizontal: Bool = false,
        physicalWheelOnly: Bool = true,
        preserveTrackpadDirection: Bool = true,
        magicMouseScrollStrategy: MagicMouseScrollStrategy = .preserve,
        smoothScrollingEnabled: Bool = true,
        smoothSteps: Int = 8,
        smoothDurationMilliseconds: Int = 120,
        smoothCurve: SmoothCurve = .easeOut,
        smoothSpeedMultiplier: Double = 1.0,
        smoothHorizontalEnabled: Bool = false,
        smoothInertiaEnabled: Bool = false,
        buttonMappingEnabled: Bool = true,
        hasCompletedOnboarding: Bool = false,
        launchAtLogin: Bool = false,
        language: AppLanguage = .system,
        menuBarVisible: Bool = true,
        showSettingsAtLaunch: Bool = false,
        excludedBundleIdentifiers: [String] = [],
        deviceOverrides: [String: InputDeviceKind] = [:],
        buttonMappings: [ButtonMapping] = [
            ButtonMapping(mouseButtonNumber: 4, shortcut: KeyboardShortcutDefinition(keyCode: 8, modifiersRawValue: CGEventFlags.maskCommand.rawValue)),
            ButtonMapping(mouseButtonNumber: 5, shortcut: KeyboardShortcutDefinition(keyCode: 9, modifiersRawValue: CGEventFlags.maskCommand.rawValue))
        ]
    ) {
        self.schemaVersion = schemaVersion
        self.masterEnabled = masterEnabled
        self.reverseMouseWheelEnabled = reverseMouseWheelEnabled
        self.reverseVertical = reverseVertical
        self.reverseHorizontal = reverseHorizontal
        self.physicalWheelOnly = physicalWheelOnly
        self.preserveTrackpadDirection = preserveTrackpadDirection
        self.magicMouseScrollStrategy = magicMouseScrollStrategy
        self.smoothScrollingEnabled = smoothScrollingEnabled
        self.smoothSteps = smoothSteps
        self.smoothDurationMilliseconds = smoothDurationMilliseconds
        self.smoothCurve = smoothCurve
        self.smoothSpeedMultiplier = smoothSpeedMultiplier
        self.smoothHorizontalEnabled = smoothHorizontalEnabled
        self.smoothInertiaEnabled = smoothInertiaEnabled
        self.buttonMappingEnabled = buttonMappingEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.launchAtLogin = launchAtLogin
        self.language = language
        self.menuBarVisible = menuBarVisible
        self.showSettingsAtLaunch = showSettingsAtLaunch
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
        self.deviceOverrides = deviceOverrides
        self.buttonMappings = buttonMappings
        normalize()
    }

    static let defaults = AppSettings()

    var shouldShowMenuBarExtra: Bool {
        !hasCompletedOnboarding || menuBarVisible
    }

    var shouldOpenSettingsWindowAtLaunch: Bool {
        !hasCompletedOnboarding || showSettingsAtLaunch || !menuBarVisible
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case masterEnabled
        case reverseMouseWheelEnabled
        case reverseVertical
        case reverseHorizontal
        case physicalWheelOnly
        case preserveTrackpadDirection
        case magicMouseScrollStrategy
        case smoothScrollingEnabled
        case smoothSteps
        case smoothDurationMilliseconds
        case smoothCurve
        case smoothSpeedMultiplier
        case smoothHorizontalEnabled
        case smoothInertiaEnabled
        case buttonMappingEnabled
        case hasCompletedOnboarding
        case launchAtLogin
        case language
        case menuBarVisible
        case showSettingsAtLaunch
        case excludedBundleIdentifiers
        case deviceOverrides
        case buttonMappings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        masterEnabled = try container.decodeIfPresent(Bool.self, forKey: .masterEnabled) ?? true
        reverseMouseWheelEnabled = try container.decodeIfPresent(Bool.self, forKey: .reverseMouseWheelEnabled) ?? true
        reverseVertical = try container.decodeIfPresent(Bool.self, forKey: .reverseVertical) ?? true
        reverseHorizontal = try container.decodeIfPresent(Bool.self, forKey: .reverseHorizontal) ?? false
        physicalWheelOnly = try container.decodeIfPresent(Bool.self, forKey: .physicalWheelOnly) ?? true
        preserveTrackpadDirection = try container.decodeIfPresent(Bool.self, forKey: .preserveTrackpadDirection) ?? true
        magicMouseScrollStrategy = try container.decodeIfPresent(MagicMouseScrollStrategy.self, forKey: .magicMouseScrollStrategy) ?? .preserve
        smoothScrollingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothScrollingEnabled) ?? true
        smoothSteps = try container.decodeIfPresent(Int.self, forKey: .smoothSteps) ?? 8
        smoothDurationMilliseconds = try container.decodeIfPresent(Int.self, forKey: .smoothDurationMilliseconds) ?? 120
        smoothCurve = try container.decodeIfPresent(SmoothCurve.self, forKey: .smoothCurve) ?? .easeOut
        smoothSpeedMultiplier = try container.decodeIfPresent(Double.self, forKey: .smoothSpeedMultiplier) ?? 1.0
        smoothHorizontalEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothHorizontalEnabled) ?? false
        smoothInertiaEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothInertiaEnabled) ?? false
        buttonMappingEnabled = try container.decodeIfPresent(Bool.self, forKey: .buttonMappingEnabled) ?? true
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        menuBarVisible = try container.decodeIfPresent(Bool.self, forKey: .menuBarVisible) ?? true
        showSettingsAtLaunch = try container.decodeIfPresent(Bool.self, forKey: .showSettingsAtLaunch) ?? false
        excludedBundleIdentifiers = try container.decodeIfPresent([String].self, forKey: .excludedBundleIdentifiers) ?? []
        deviceOverrides = try container.decodeIfPresent([String: InputDeviceKind].self, forKey: .deviceOverrides) ?? [:]
        buttonMappings = try container.decodeIfPresent([ButtonMapping].self, forKey: .buttonMappings) ?? AppSettings.defaults.buttonMappings
        normalize()
    }

    mutating func normalize() {
        schemaVersion = max(schemaVersion, 1)
        smoothSteps = min(max(smoothSteps, 1), 20)
        smoothDurationMilliseconds = min(max(smoothDurationMilliseconds, 40), 240)
        smoothSpeedMultiplier = min(max(smoothSpeedMultiplier, 0.1), 5.0)
        var seenBundleIdentifiers = Set<String>()
        excludedBundleIdentifiers = excludedBundleIdentifiers.compactMap { bundleIdentifier in
            let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seenBundleIdentifiers.contains(trimmed) else { return nil }
            seenBundleIdentifiers.insert(trimmed)
            return trimmed
        }
        var seenButtons = Set<Int>()
        buttonMappings = buttonMappings.filter { mapping in
            guard mapping.mouseButtonNumber >= 3 else { return false }
            guard mapping.action.isValid else { return false }
            guard !seenButtons.contains(mapping.mouseButtonNumber) else { return false }
            seenButtons.insert(mapping.mouseButtonNumber)
            return true
        }
    }

    func runtimeSnapshot(permissions: PermissionSummary) -> RuntimeConfigSnapshot {
        RuntimeConfigSnapshot(
            masterEnabled: masterEnabled,
            canProcessEvents: permissions.canProcessEvents,
            reverseMouseWheelEnabled: reverseMouseWheelEnabled,
            reverseVertical: reverseVertical,
            reverseHorizontal: reverseHorizontal,
            physicalWheelOnly: physicalWheelOnly,
            preserveTrackpadDirection: preserveTrackpadDirection,
            magicMouseScrollStrategy: magicMouseScrollStrategy,
            smoothScrollingEnabled: smoothScrollingEnabled,
            smoothSteps: smoothSteps,
            smoothDurationMilliseconds: smoothDurationMilliseconds,
            smoothCurve: smoothCurve,
            smoothSpeedMultiplier: smoothSpeedMultiplier,
            smoothHorizontalEnabled: smoothHorizontalEnabled,
            smoothInertiaEnabled: smoothInertiaEnabled,
            buttonMappingEnabled: buttonMappingEnabled,
            hasCompletedOnboarding: hasCompletedOnboarding,
            buttonMappings: buttonMappings.filter(\.isEnabled),
            excludedBundleIdentifiers: Set(excludedBundleIdentifiers),
            deviceOverrides: deviceOverrides
        )
    }
}

public struct RuntimeConfigSnapshot: Equatable, Sendable {
    var masterEnabled: Bool
    var canProcessEvents: Bool
    var reverseMouseWheelEnabled: Bool
    var reverseVertical: Bool
    var reverseHorizontal: Bool
    var physicalWheelOnly: Bool
    var preserveTrackpadDirection: Bool
    var magicMouseScrollStrategy: MagicMouseScrollStrategy
    var smoothScrollingEnabled: Bool
    var smoothSteps: Int
    var smoothDurationMilliseconds: Int
    var smoothCurve: SmoothCurve
    var smoothSpeedMultiplier: Double
    var smoothHorizontalEnabled: Bool
    var smoothInertiaEnabled: Bool
    var buttonMappingEnabled: Bool
    var hasCompletedOnboarding: Bool
    var buttonMappings: [ButtonMapping]
    var excludedBundleIdentifiers: Set<String>
    var deviceOverrides: [String: InputDeviceKind]

    static let disabled = RuntimeConfigSnapshot(
        masterEnabled: false,
        canProcessEvents: false,
        reverseMouseWheelEnabled: false,
        reverseVertical: false,
        reverseHorizontal: false,
        physicalWheelOnly: true,
        preserveTrackpadDirection: true,
        magicMouseScrollStrategy: .preserve,
        smoothScrollingEnabled: false,
        smoothSteps: 1,
        smoothDurationMilliseconds: 120,
        smoothCurve: .easeOut,
        smoothSpeedMultiplier: 1,
        smoothHorizontalEnabled: false,
        smoothInertiaEnabled: false,
        buttonMappingEnabled: false,
        hasCompletedOnboarding: false,
        buttonMappings: [],
        excludedBundleIdentifiers: [],
        deviceOverrides: [:]
    )

    var shouldHandleEvents: Bool {
        masterEnabled && canProcessEvents && hasCompletedOnboarding
    }

    var inactiveEventTapStatus: EventTapRuntimeStatus {
        if hasCompletedOnboarding && masterEnabled && !canProcessEvents {
            return .missingPermissions
        }
        return .stopped
    }

    func shouldHandleEvents(for bundleIdentifier: String?) -> Bool {
        guard shouldHandleEvents else { return false }
        guard let bundleIdentifier else { return true }
        return !excludedBundleIdentifiers.contains(bundleIdentifier)
    }
}

public struct DiagnosticsLogEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    var timestamp: Date
    var level: String
    var message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), level: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}
