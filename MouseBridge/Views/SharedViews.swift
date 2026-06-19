import AppKit
import SwiftUI

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            content
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SettingsToggleRow: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleKey)
                Text(subtitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(titleKey))
        .accessibilityHint(Text(subtitleKey))
    }
}

struct StatusPill: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(titleKey, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct FeatureAvailabilityNoticeBanner: View {
    let messageKey: String

    var body: some View {
        Label(LocalizedStringKey(messageKey), systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcutDefinition?
    var isActive = true
    var recorderMode: ShortcutRecorderMode = .singleChord
    @Binding var assembly: ShortcutKeyAssemblySession
    var onComplete: () -> Void = {}
    var onCancel: () -> Void = {}

    init(
        shortcut: Binding<KeyboardShortcutDefinition?>,
        isActive: Bool = true,
        recorderMode: ShortcutRecorderMode = .singleChord,
        assembly: Binding<ShortcutKeyAssemblySession> = .constant(ShortcutKeyAssemblySession()),
        onComplete: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        _shortcut = shortcut
        self.isActive = isActive
        self.recorderMode = recorderMode
        _assembly = assembly
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.isActive = isActive
        configure(view)
        focusIfNeeded(view)
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        let wasActive = nsView.isActive
        nsView.isActive = isActive
        configure(nsView)
        if isActive && !wasActive {
            focusIfNeeded(nsView)
        }
    }

    private func configure(_ view: KeyCaptureView) {
        view.onCapture = { event in
            handleKeyDown(event)
        }
        view.onModifierCapture = { event in
            handleModifierChange(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        switch recorderMode {
        case .singleChord:
            let usefulFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let decision = ShortcutCaptureInterpreter().interpret(
                keyCode: UInt16(event.keyCode),
                modifiersRawValue: CGEventFlags(maskFrom: usefulFlags).rawValue
            )
            switch decision {
            case .capture(let definition):
                shortcut = definition
            case .cancel:
                onCancel()
            case .clear:
                shortcut = nil
            case .invalid:
                NSSound.beep()
            }
        case .separateKeys:
            switch event.keyCode {
            case 53:
                onCancel()
            case 51, 117:
                assembly.clear()
                shortcut = nil
            default:
                appendAssemblyKey(.key(keyCode: UInt16(event.keyCode)))
            }
        }
    }

    private func handleModifierChange(_ event: NSEvent) {
        guard recorderMode == .separateKeys,
              let flagRawValue = ShortcutCaptureInterpreter.modifierFlag(for: UInt16(event.keyCode)) else {
            return
        }
        let usefulFlags = CGEventFlags(maskFrom: event.modifierFlags.intersection([.command, .option, .control, .shift]))
        guard usefulFlags.contains(CGEventFlags(rawValue: flagRawValue)) else { return }
        appendAssemblyKey(.modifier(keyCode: UInt16(event.keyCode), flagRawValue: flagRawValue))
    }

    private func appendAssemblyKey(_ key: ShortcutAssemblyKey) {
        switch assembly.append(key) {
        case .inProgress, .duplicate:
            break
        case .complete(let definition):
            shortcut = definition
            onComplete()
        case .full, .invalid:
            NSSound.beep()
        }
    }

    private func focusIfNeeded(_ view: KeyCaptureView) {
        DispatchQueue.main.async {
            guard view.isActive else { return }
            view.window?.makeFirstResponder(view)
        }
    }
}

final class KeyCaptureView: NSView {
    var onCapture: ((NSEvent) -> Void)?
    var onModifierCapture: ((NSEvent) -> Void)?
    var isActive = true

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isActive else { return }
        onCapture?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isActive else { return }
        onModifierCapture?(event)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}

extension CGEventFlags {
    init(maskFrom modifierFlags: NSEvent.ModifierFlags) {
        var flags: CGEventFlags = []
        if modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        self = flags
    }
}

extension View {
    func settingPagePadding() -> some View {
        self.padding(.horizontal, 24).padding(.vertical, 18)
    }
}
