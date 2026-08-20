import AppKit
import MyQuickFinderKit
import SwiftUI

enum PanelKeyboard {
    private static let namedKeys: [Character: KeyChord.Key] = [
        KeyEquivalent.upArrow.character: .up,
        KeyEquivalent.downArrow.character: .down,
        KeyEquivalent.leftArrow.character: .left,
        KeyEquivalent.rightArrow.character: .right,
        KeyEquivalent.tab.character: .tab,
        KeyEquivalent.return.character: .return,
        KeyEquivalent.escape.character: .escape,
    ]

    static var isPathFieldFocused: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    static var isComposingInPathField: Bool {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        return editor.hasMarkedText()
    }

    static func chord(from press: KeyPress) -> KeyChord {
        KeyChord(key(for: press.key.character), .swiftUI(press.modifiers.rawValue))
    }

    static func chord(from event: NSEvent) -> KeyChord? {
        guard let character = event.charactersIgnoringModifiers?.first else {
            return nil
        }
        return KeyChord(key(for: character), .appKit(event.modifierFlags.rawValue))
    }

    static func key(for character: Character) -> KeyChord.Key {
        namedKeys[character] ?? .character(character)
    }

    static func focusPathField() {
        Task { @MainActor in
            guard
                let window = NSApp.keyWindow,
                let field = pathField(in: window.contentView)
            else {
                return
            }
            window.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
    }

    static func moveCaretToPathEnd() {
        guard
            let window = NSApp.keyWindow,
            let field = pathField(in: window.contentView)
        else {
            return
        }
        field.moveCaretToEnd?()
    }

    private static func pathField(in view: NSView?) -> PathNSTextField? {
        guard let view else {
            return nil
        }
        if let field = view as? PathNSTextField {
            return field
        }
        for child in view.subviews {
            if let found = pathField(in: child) {
                return found
            }
        }
        return nil
    }
}
