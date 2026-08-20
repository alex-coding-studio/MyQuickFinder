import AppKit
import Carbon.HIToolbox
import MyQuickFinderKit
import SwiftUI

enum HotKeyTranslation {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) {
            value |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            value |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            value |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            value |= UInt32(shiftKey)
        }
        return value
    }
}

struct HotKeyRecorderField: NSViewRepresentable {
    @MainActor
    final class Coordinator {
        var isRecording = false
        var onRecord: ((HotKeyBinding) -> Void)?

        private var monitor: Any?

        init() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, isRecording else {
                    return event
                }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let carbon = HotKeyTranslation.carbonModifiers(from: flags)
                guard carbon != 0 else {
                    return event
                }
                onRecord?(
                    HotKeyBinding(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
                )
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }

    let binding: HotKeyBinding
    let isRecording: Bool
    let onRecord: (HotKeyBinding) -> Void

    static func dismantleNSView(_: NSTextField, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeNSView(context _: Context) -> NSTextField {
        let field = NSTextField(labelWithString: HotKeyLabel.text(for: binding))
        field.alignment = .center
        field.font = .monospacedSystemFont(
            ofSize: DesignTokens.Typography.compactFieldPointSize,
            weight: .regular
        )
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.stringValue = isRecording
            ? String(localized: "settings.keys.recorderPrompt")
            : HotKeyLabel.text(for: binding)
        field.textColor = isRecording ? .secondaryLabelColor : .labelColor
        context.coordinator.isRecording = isRecording
        context.coordinator.onRecord = onRecord
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
