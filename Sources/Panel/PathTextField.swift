import AppKit
import MyQuickFinderKit
import SwiftUI

final class PathNSTextField: NSTextField {
    var onChord: ((KeyChord) -> Bool)?
    var moveCaretToEnd: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard
            (currentEditor() as? NSTextView)?.hasMarkedText() != true,
            let chord = PanelKeyboard.chord(from: event),
            chord.modifiers == .command,
            let handled = onChord?(chord),
            handled
        else {
            return super.performKeyEquivalent(with: event)
        }
        return true
    }
}

struct PathTextField: NSViewRepresentable {
    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private static let selectorKeys: [Selector: KeyChord.Key] = [
            #selector(NSResponder.moveUp(_:)): .up,
            #selector(NSResponder.moveDown(_:)): .down,
            #selector(NSResponder.insertTab(_:)): .tab,
            #selector(NSResponder.insertNewline(_:)): .return,
            #selector(NSResponder.cancelOperation(_:)): .escape,
            #selector(NSResponder.moveRight(_:)): .right,
        ]

        var parent: PathTextField
        var ghost = ""
        var lastTyped = ""
        var suppressGhost = false
        var lastSelectAllToken = 0
        var lastTextChangeEvent: TimeInterval?

        private var isCommittingComposition: Bool {
            guard
                let changed = lastTextChangeEvent,
                let current = NSApp.currentEvent?.timestamp
            else {
                return false
            }
            return changed == current
        }

        init(_ parent: PathTextField) {
            self.parent = parent
        }

        private static func tail(of suggestion: String?, after typed: String) -> String {
            guard
                let suggestion,
                typed.isEmpty == false,
                suggestion.count > typed.count,
                suggestion.lowercased().hasPrefix(typed.lowercased())
            else {
                return ""
            }
            return String(suggestion.dropFirst(typed.count))
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else {
                return
            }
            lastTextChangeEvent = NSApp.currentEvent?.timestamp
            let raw = field.stringValue
            let typed = ghost.isEmpty || raw.hasSuffix(ghost) == false
                ? raw
                : String(raw.dropLast(ghost.count))
            suppressGhost = typed.count < lastTyped.count
            lastTyped = typed
            ghost = ""
            parent.onEdit(typed)
        }

        func render(
            text: String,
            suggestion: String?,
            selectAllToken: Int,
            in field: PathNSTextField
        ) {
            if selectAllToken != lastSelectAllToken {
                lastSelectAllToken = selectAllToken
                ghost = ""
                lastTyped = text
                if let editor = field.currentEditor() as? NSTextView {
                    editor.string = text
                    editor.selectedRange = NSRange(location: 0, length: text.count)
                } else {
                    field.stringValue = text
                }
                return
            }
            guard let editor = field.currentEditor() as? NSTextView else {
                if field.stringValue != text {
                    field.stringValue = text
                }
                ghost = ""
                lastTyped = text
                return
            }
            let selection = editor.selectedRange()
            if selection.length > 0, editor.string == text {
                ghost = ""
                lastTyped = text
                return
            }
            let tail = suppressGhost ? "" : Self.tail(of: suggestion, after: text)
            let desired = text + tail
            guard editor.string != desired else {
                ghost = tail
                return
            }
            editor.string = desired
            if tail.isEmpty == false {
                editor.textStorage?.addAttribute(
                    .foregroundColor,
                    value: NSColor.tertiaryLabelColor,
                    range: NSRange(location: text.count, length: tail.count)
                )
            }
            editor.selectedRange = NSRange(location: text.count, length: 0)
            ghost = tail
            lastTyped = text
        }

        func control(
            _: NSControl,
            textView: NSTextView,
            doCommandBy selector: Selector
        ) -> Bool {
            guard let key = Self.selectorKeys[selector] else {
                return false
            }
            return parent.onChord(KeyChord(key), state(of: textView))
        }

        func moveCaretToEnd(in field: PathNSTextField) {
            guard let editor = field.currentEditor() as? NSTextView else {
                return
            }
            let typedLength = min(parent.text.count, editor.string.count)
            editor.selectedRange = NSRange(location: typedLength, length: 0)
        }

        private func state(of textView: NSTextView) -> PathFieldFacts {
            let range = textView.selectedRange()
            return PathFieldFacts(
                selectionLength: range.length,
                caretLocation: range.location,
                isComposing: textView.hasMarkedText() || isCommittingComposition
            )
        }
    }

    let text: String
    let suggestion: String?
    let placeholder: String
    let selectAllToken: Int
    let onEdit: (String) -> Void
    let onChord: (KeyChord, PathFieldFacts) -> Bool

    func makeNSView(context: Context) -> PathNSTextField {
        let field = PathNSTextField(string: text)
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: DesignTokens.Typography.fieldPointSize)
        field.lineBreakMode = .byTruncatingHead
        field.placeholderString = placeholder
        field.cell?.sendsActionOnEndEditing = false
        field.onChord = commandChordHandler()
        field.moveCaretToEnd = { [weak field, weak coordinator = context.coordinator] in
            guard let field, let coordinator else {
                return
            }
            coordinator.moveCaretToEnd(in: field)
        }
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: PathNSTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        field.onChord = commandChordHandler()
        field.moveCaretToEnd = { [weak field, weak coordinator] in
            guard let field, let coordinator else {
                return
            }
            coordinator.moveCaretToEnd(in: field)
        }
        coordinator.render(
            text: text,
            suggestion: suggestion,
            selectAllToken: selectAllToken,
            in: field
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func commandChordHandler() -> (KeyChord) -> Bool {
        { chord in
            onChord(
                chord,
                PathFieldFacts(selectionLength: 0, caretLocation: text.count, isComposing: false)
            )
        }
    }
}
