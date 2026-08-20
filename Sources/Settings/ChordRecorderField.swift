import AppKit
import MyQuickFinderKit
import SwiftUI

struct ChordRecorderField: NSViewRepresentable {
    @MainActor
    final class Coordinator {
        var isRecording = false
        var onRecord: ((KeyChord) -> Void)?

        private var monitor: Any?

        init() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, isRecording else {
                    return event
                }
                guard
                    let chord = PanelKeyboard.chord(from: event),
                    !chord.modifiers.isEmpty
                else {
                    return event
                }
                onRecord?(chord)
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

    let chord: KeyChord?
    let isRecording: Bool
    let onRecord: (KeyChord) -> Void

    static func dismantleNSView(_: NSTextField, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeNSView(context _: Context) -> NSTextField {
        let field = NSTextField(labelWithString: "")
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
            : chord.map(KeyChordFormatter.spaced) ?? ""
        field.textColor = isRecording ? .secondaryLabelColor : .labelColor
        context.coordinator.isRecording = isRecording
        context.coordinator.onRecord = onRecord
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
