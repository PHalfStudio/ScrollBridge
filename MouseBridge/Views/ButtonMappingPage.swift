import Combine
import SwiftUI

struct ButtonMappingPage: View {
    @EnvironmentObject private var appState: AppState
    @State private var editingMapping: ButtonMapping?
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: boolBinding(\.buttonMappingEnabled)) {
                        Text("mapping.enabled")
                    }
                    .accessibilityLabel(Text("mapping.enabled"))
                    .accessibilityHint(Text("mapping.enabled.hint"))
                    Text("mapping.privacyNote")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let noticeKey = appState.featureAvailabilityNoticeKey {
                FeatureAvailabilityNoticeBanner(messageKey: noticeKey)
            }

            List {
                ForEach(appState.settings.buttonMappings) { mapping in
                    HStack(spacing: 12) {
                        Image(systemName: mapping.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mapping.isEnabled ? .green : .secondary)
                        let summary = ButtonMappingListSummary(mapping: mapping)
                        let buttonTitle = String(format: NSLocalizedString("mapping.buttonFormat", comment: ""), mapping.mouseButtonNumber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.name ?? buttonTitle)
                            Text(summary.name == nil ? summary.actionDisplayName : "\(buttonTitle) · \(summary.actionDisplayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                Label(LocalizedStringKey(summary.scopeKey), systemImage: "scope")
                                Label(summary.note, systemImage: "note.text")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("mapping.edit") {
                            editingMapping = mapping
                            showingEditor = true
                        }
                        .accessibilityLabel(Text("mapping.edit"))
                        .accessibilityHint(Text("mapping.edit.hint"))
                        Button("mapping.delete", role: .destructive) {
                            appState.removeMapping(mapping)
                        }
                        .accessibilityLabel(Text("mapping.delete"))
                        .accessibilityHint(Text("mapping.delete.hint"))
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(mappingAccessibilityLabel(for: mapping)))
                    .accessibilityHint(Text("mapping.row.accessibilityHint"))
                }
            }
            .frame(minHeight: 240)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }

            HStack {
                Button {
                    editingMapping = nil
                    showingEditor = true
                } label: {
                    Label("mapping.add", systemImage: "plus")
                }
                .accessibilityLabel(Text("mapping.add"))
                .accessibilityHint(Text("mapping.add.hint"))
                Spacer()
                if let last = appState.lastMouseButtonNumber {
                    Text(String(format: NSLocalizedString("mapping.lastButton", comment: ""), last))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .settingPagePadding()
        .navigationTitle("page.buttonMapping")
        .sheet(isPresented: $showingEditor) {
            MappingEditorSheet(mapping: editingMapping)
                .environmentObject(appState)
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { appState.settings[keyPath: keyPath] }, set: { value in appState.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private func mappingAccessibilityLabel(for mapping: ButtonMapping) -> String {
        let summary = ButtonMappingListSummary(mapping: mapping)
        let format = NSLocalizedString("mapping.row.accessibilityLabelFormat", comment: "")
        return String(
            format: format,
            mapping.mouseButtonNumber,
            summary.actionDisplayName,
            NSLocalizedString(summary.scopeKey, comment: ""),
            summary.note
        )
    }
}

struct MappingEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedTextField: MappingEditorFocusedField?
    @State private var mappingID: UUID
    @State private var isEnabled: Bool
    @State private var name: String
    @State private var mouseButtonNumber: Int
    @State private var actionSelection: MappingEditorActionSelection
    @State private var shortcut: KeyboardShortcutDefinition?
    @State private var presetShortcutID: String
    @State private var systemActionID: String
    @State private var shortcutRecorderMode: ShortcutRecorderMode
    @State private var shortcutAssembly: ShortcutKeyAssemblySession
    @State private var scope: String
    @State private var note: String
    @State private var recordingSession: ShortcutRecordingSession
    @State private var mouseButtonRecordingSession: MouseButtonRecordingSession?
    @State private var now: Date
    private let recordingTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(mapping: ButtonMapping?) {
        let initialDate = Date()
        _mappingID = State(initialValue: mapping?.id ?? UUID())
        _isEnabled = State(initialValue: mapping?.isEnabled ?? true)
        _name = State(initialValue: mapping?.name ?? "")
        let draft = mapping.map { ButtonMappingEditorDraft(mouseButtonNumber: $0.mouseButtonNumber, action: $0.action) } ?? .newMapping
        let keyboardShortcut = draft.action?.keyboardShortcut
        let matchedPresetID = keyboardShortcut.flatMap { MacOSPresetShortcut.preset(matching: $0)?.id }
        let systemAction = draft.action?.systemAction
        _mouseButtonNumber = State(initialValue: draft.mouseButtonNumber)
        _actionSelection = State(initialValue: systemAction != nil ? .systemAction : (matchedPresetID != nil ? .presetShortcut : .manualRecord))
        _shortcut = State(initialValue: keyboardShortcut)
        _presetShortcutID = State(initialValue: matchedPresetID ?? MacOSPresetShortcut.allCases.first?.id ?? "spotlight")
        _systemActionID = State(initialValue: systemAction?.rawValue ?? MacOSSystemActionPreset.allCases.first?.id ?? SystemMappingAction.missionControl.rawValue)
        _shortcutRecorderMode = State(initialValue: .singleChord)
        _shortcutAssembly = State(initialValue: ShortcutKeyAssemblySession())
        _scope = State(initialValue: mapping?.scope ?? "global")
        _note = State(initialValue: mapping?.note ?? "")
        _recordingSession = State(initialValue: ShortcutRecordingSession(startedAt: initialDate))
        _mouseButtonRecordingSession = State(initialValue: nil)
        _now = State(initialValue: initialDate)
    }

    var body: some View {
        let isMouseButtonRecording = mouseButtonRecordingSession?.isActive(at: now) == true
        let conflictMessageKey = currentConflictMessageKey
        let canRecordShortcut = currentDraft.canRecordShortcut
        let isRecording = actionSelection == .manualRecord && focusedTextField == nil && canRecordShortcut && recordingSession.isActive(at: now)
        let shortcutHintKey = manualShortcutHintKey(isRecording: isRecording, canRecordShortcut: canRecordShortcut)
        VStack(alignment: .leading, spacing: 18) {
            Text("mapping.editor.title")
                .font(.title2.weight(.semibold))
            Toggle("mapping.editor.enabled", isOn: $isEnabled)
                .accessibilityLabel(Text("mapping.editor.enabled"))
                .accessibilityHint(Text("mapping.editor.enabled.hint"))
            TextField("mapping.editor.name", text: $name)
                .accessibilityLabel(Text("mapping.editor.name"))
                .accessibilityHint(Text("mapping.editor.name.hint"))
                .focused($focusedTextField, equals: .name)
            Picker("mapping.editor.mouseButton", selection: $mouseButtonNumber) {
                Text("mapping.editor.mouseButton.unselected").tag(0)
                ForEach(3...12, id: \.self) { number in
                    Text(String(format: NSLocalizedString("mapping.buttonFormat", comment: ""), number)).tag(number)
                }
            }
            .accessibilityLabel(Text("mapping.editor.mouseButton"))
            .accessibilityHint(Text("mapping.editor.mouseButton.hint"))
            HStack(spacing: 12) {
                Button("mapping.editor.mouseButton.record") {
                    startMouseButtonRecording()
                }
                .accessibilityLabel(Text("mapping.editor.mouseButton.record"))
                .accessibilityHint(Text("mapping.editor.mouseButton.record.hint"))
                .disabled(isMouseButtonRecording)
                if let last = appState.lastMouseButtonNumber {
                    Button(String(format: NSLocalizedString("mapping.useLastButton", comment: ""), last)) {
                        mouseButtonNumber = last
                    }
                    .accessibilityLabel(Text(String(format: NSLocalizedString("mapping.useLastButton", comment: ""), last)))
                    .accessibilityHint(Text("mapping.useLastButton.hint"))
                }
            }
            Text(isMouseButtonRecording ? "mapping.editor.mouseButton.recording" : "mapping.editor.mouseButton.recordHint")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let warningKey = ButtonMappingRiskWarning.messageKey(for: mouseButtonNumber) {
                Label(LocalizedStringKey(warningKey), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let conflictMessageKey {
                Label(LocalizedStringKey(conflictMessageKey), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 8) {
                Picker("mapping.editor.actionType", selection: $actionSelection) {
                    Text("mapping.editor.actionType.manualRecord").tag(MappingEditorActionSelection.manualRecord)
                    Text("mapping.editor.actionType.presetShortcut").tag(MappingEditorActionSelection.presetShortcut)
                    Text("mapping.editor.actionType.systemAction").tag(MappingEditorActionSelection.systemAction)
                }
                .accessibilityLabel(Text("mapping.editor.actionType"))
                .accessibilityHint(Text("mapping.editor.actionType.hint"))
                Text(LocalizedStringKey(actionSelection.descriptionKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if actionSelection == .presetShortcut {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("mapping.editor.presetShortcut", selection: $presetShortcutID) {
                        ForEach(MacOSPresetShortcut.allCases) { preset in
                            Text(LocalizedStringKey(preset.titleKey)).tag(preset.id)
                        }
                    }
                    .accessibilityLabel(Text("mapping.editor.presetShortcut"))
                    .accessibilityHint(Text("mapping.editor.presetShortcut.hint"))
                    Text(LocalizedStringKey(selectedPresetDescriptionKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if actionSelection == .systemAction {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("mapping.editor.systemAction", selection: $systemActionID) {
                        ForEach(MacOSSystemActionPreset.allCases) { preset in
                            Text(LocalizedStringKey(preset.titleKey)).tag(preset.id)
                        }
                    }
                    .accessibilityLabel(Text("mapping.editor.systemAction"))
                    .accessibilityHint(Text("mapping.editor.systemAction.hint"))
                    Text(LocalizedStringKey(selectedSystemActionDescriptionKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if actionSelection == .manualRecord {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("mapping.editor.shortcut.recordingMode", selection: $shortcutRecorderMode) {
                        ForEach(ShortcutRecorderMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                        }
                    }
                    .accessibilityLabel(Text("mapping.editor.shortcut.recordingMode"))
                    .accessibilityHint(Text("mapping.editor.shortcut.recordingMode.hint"))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(actionSelection == .systemAction ? "mapping.editor.systemAction" : "mapping.editor.shortcut")
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary)
                    Text(actionDisplayText)
                        .font(.title3.monospaced())
                    if actionSelection == .manualRecord {
                        ShortcutRecorderView(
                            shortcut: $shortcut,
                            isActive: isRecording,
                            recorderMode: shortcutRecorderMode,
                            assembly: $shortcutAssembly,
                            onComplete: {
                                cancelShortcutRecording()
                            },
                            onCancel: {
                                cancelShortcutRecording()
                            }
                        )
                            .frame(height: 54)
                            .accessibilityLabel(Text("mapping.editor.shortcut.capture"))
                            .accessibilityHint(Text("mapping.editor.shortcut.captureHint"))
                    }
                }
                .frame(height: 54)
                Text(LocalizedStringKey(shortcutHintKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if actionSelection == .manualRecord {
                    Button("mapping.editor.rerecord") {
                        restartRecording(clearAssembly: true)
                    }
                    .accessibilityLabel(Text("mapping.editor.rerecord"))
                    .accessibilityHint(Text("mapping.editor.rerecord.hint"))
                    .disabled(!canRecordShortcut)
                }
            }
            HStack {
                Text("mapping.editor.scope")
                Spacer()
                Text("mapping.scope.global")
                    .foregroundStyle(.secondary)
            }
            TextField("mapping.editor.note", text: $note)
                .accessibilityLabel(Text("mapping.editor.note"))
                .accessibilityHint(Text("mapping.editor.note.hint"))
                .focused($focusedTextField, equals: .note)
            HStack {
                Spacer()
                Button("action.cancel") { dismiss() }
                    .accessibilityLabel(Text("action.cancel"))
                    .accessibilityHint(Text("action.cancel.hint"))
                Button("action.save") { save() }
                    .accessibilityLabel(Text("action.save"))
                    .accessibilityHint(Text("action.save.hint"))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!currentDraft.canSave(conflictMessageKey: conflictMessageKey))
            }
        }
        .padding(24)
        .frame(width: 460)
        .onReceive(recordingTimer) { date in
            now = date
            expireMouseButtonRecordingIfNeeded(at: date)
        }
        .onChange(of: appState.lastMouseButtonCapture) { _, event in
            captureMouseButton(from: event)
        }
        .onChange(of: mouseButtonNumber) { oldValue, newValue in
            let previousDraft = ButtonMappingEditorDraft(mouseButtonNumber: oldValue, action: currentAction)
            if actionSelection == .manualRecord && previousDraft.shouldRestartShortcutRecording(afterChangingMouseButtonTo: newValue) {
                restartRecording(clearAssembly: true)
            }
        }
        .onChange(of: actionSelection) { _, newValue in
            applyActionSelection(newValue)
        }
        .onChange(of: presetShortcutID) { _, newValue in
            applyPresetShortcutSelection(newValue)
        }
        .onChange(of: systemActionID) { _, newValue in
            applySystemActionSelection(newValue)
        }
        .onChange(of: shortcutRecorderMode) { _, _ in
            resetManualShortcutRecording()
        }
        .onChange(of: focusedTextField) { _, newValue in
            handleTextFieldFocusChange(newValue)
        }
    }

    private func save() {
        guard let action = currentAction else { return }
        guard currentDraft.canSave(conflictMessageKey: currentConflictMessageKey) else { return }
        let mapping = ButtonMapping(
            id: mappingID,
            isEnabled: isEnabled,
            name: name,
            mouseButtonNumber: mouseButtonNumber,
            action: action,
            scope: scope,
            note: note
        )
        if appState.addOrReplaceMapping(mapping) {
            dismiss()
        }
    }

    private var currentConflictMessageKey: String? {
        guard let action = currentAction else { return nil }
        let mapping = ButtonMapping(
            id: mappingID,
            isEnabled: isEnabled,
            name: name,
            mouseButtonNumber: mouseButtonNumber,
            action: action,
            scope: scope,
            note: note
        )
        return ButtonMappingConflictWarning.messageKey(for: mapping, in: appState.settings.buttonMappings)
    }

    private var currentDraft: ButtonMappingEditorDraft {
        ButtonMappingEditorDraft(mouseButtonNumber: mouseButtonNumber, action: currentAction)
    }

    private var currentAction: ButtonMappingAction? {
        switch actionSelection {
        case .manualRecord:
            shortcut.map { .keyboardShortcut($0) }
        case .presetShortcut:
            MacOSPresetShortcut.preset(id: presetShortcutID).map { .keyboardShortcut($0.shortcut) }
        case .systemAction:
            MacOSSystemActionPreset.preset(id: systemActionID).map { .systemAction($0.action) }
        }
    }

    private var actionDisplayText: String {
        if actionSelection == .manualRecord, shortcut == nil, !shortcutAssembly.keys.isEmpty {
            return shortcutAssembly.displayName
        }
        return currentAction?.displayName ?? "—"
    }

    private var selectedPresetDescriptionKey: String {
        MacOSPresetShortcut.preset(id: presetShortcutID)?.descriptionKey ?? "mapping.editor.presetShortcut.empty"
    }

    private var selectedSystemActionDescriptionKey: String {
        MacOSSystemActionPreset.preset(id: systemActionID)?.descriptionKey ?? "mapping.editor.systemAction.empty"
    }

    private func manualShortcutHintKey(isRecording: Bool, canRecordShortcut: Bool) -> String {
        switch actionSelection {
        case .manualRecord:
            guard canRecordShortcut else { return "mapping.editor.shortcut.waitForMouseButton" }
            return isRecording ? shortcutRecorderMode.hintKey : "mapping.editor.shortcut.timeout"
        case .presetShortcut:
            return "mapping.editor.shortcut.presetSelected"
        case .systemAction:
            return "mapping.editor.systemAction.selected"
        }
    }

    private func applyActionSelection(_ selection: MappingEditorActionSelection) {
        switch selection {
        case .manualRecord:
            resetManualShortcutRecording()
        case .presetShortcut:
            applyPresetShortcutSelection(presetShortcutID)
        case .systemAction:
            applySystemActionSelection(systemActionID)
        }
    }

    private func applyPresetShortcutSelection(_ id: String) {
        if let preset = MacOSPresetShortcut.preset(id: id) {
            shortcut = preset.shortcut
            shortcutAssembly.clear()
            cancelShortcutRecording()
        }
    }

    private func applySystemActionSelection(_ id: String) {
        guard MacOSSystemActionPreset.preset(id: id) != nil else { return }
        shortcut = nil
        shortcutAssembly.clear()
        cancelShortcutRecording()
    }

    private func handleTextFieldFocusChange(_ focusedField: MappingEditorFocusedField?) {
        if focusedField != nil {
            cancelShortcutRecording()
        } else if actionSelection == .manualRecord && currentDraft.canRecordShortcut && shortcut == nil {
            restartRecording(clearAssembly: false)
        }
    }

    private func resetManualShortcutRecording() {
        shortcut = nil
        shortcutAssembly.clear()
        if currentDraft.canRecordShortcut {
            restartRecording(clearAssembly: false)
        } else {
            cancelShortcutRecording()
        }
    }

    private func restartRecording() {
        restartRecording(clearAssembly: true)
    }

    private func restartRecording(clearAssembly: Bool) {
        if clearAssembly {
            shortcut = nil
            shortcutAssembly.clear()
        }
        let date = Date()
        recordingSession = recordingSession.restarted(at: date)
        now = date
    }

    private func cancelShortcutRecording() {
        let date = Date()
        recordingSession = recordingSession.cancelled(at: date)
        now = date
    }

    private func startMouseButtonRecording() {
        let date = Date()
        mouseButtonRecordingSession = MouseButtonRecordingSession(
            startedAt: date,
            initialEventSequence: appState.lastMouseButtonCapture?.sequence
        )
        now = date
    }

    private func captureMouseButton(from event: MouseButtonCaptureEvent?) {
        guard let captured = mouseButtonRecordingSession?.capturedButton(from: event, at: now) else { return }
        mouseButtonNumber = captured
        mouseButtonRecordingSession = nil
    }

    private func expireMouseButtonRecordingIfNeeded(at date: Date) {
        guard let session = mouseButtonRecordingSession, !session.isActive(at: date) else { return }
        mouseButtonRecordingSession = nil
    }
}

private enum MappingEditorFocusedField: Hashable {
    case name
    case note
}

private enum MappingEditorActionSelection: String, CaseIterable, Identifiable {
    case manualRecord
    case presetShortcut
    case systemAction

    var id: String { rawValue }

    var descriptionKey: String {
        switch self {
        case .manualRecord:
            "mapping.editor.actionType.manualRecord.desc"
        case .presetShortcut:
            "mapping.editor.actionType.presetShortcut.desc"
        case .systemAction:
            "mapping.editor.actionType.systemAction.desc"
        }
    }
}
