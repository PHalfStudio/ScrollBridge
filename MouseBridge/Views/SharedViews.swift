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
    var onCancel: () -> Void = {}

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.isActive = isActive
        view.onCapture = { event in
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
        }
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isActive = isActive
        DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
    }
}

final class KeyCaptureView: NSView {
    var onCapture: ((NSEvent) -> Void)?
    var isActive = true

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isActive else { return }
        onCapture?(event)
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
