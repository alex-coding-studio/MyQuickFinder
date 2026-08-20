import AppKit
import Carbon.HIToolbox
import MyQuickFinderKit

enum HotKeyLabel {
    static func text(for binding: HotKeyBinding) -> String {
        modifierSymbols(binding.carbonModifiers) + keyName(for: binding.keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: String(localized: "key.space")
        case kVK_Return, kVK_ANSI_KeypadEnter: "↩"
        case kVK_Tab: "⇥"
        case kVK_Escape: "⎋"
        case kVK_Delete: "⌫"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        default: character(for: keyCode)?.uppercased() ?? ""
        }
    }

    private static func modifierSymbols(_ carbonModifiers: UInt32) -> String {
        var text = ""
        if carbonModifiers & UInt32(controlKey) != 0 {
            text += "⌃"
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            text += "⌥"
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            text += "⇧"
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            text += "⌘"
        }
        return text
    }

    private static func character(for keyCode: UInt32) -> String? {
        guard
            let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
            .takeRetainedValue(),
            let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer in
            guard let layout = buffer.baseAddress else {
                return nil
            }
            return translate(keyCode: keyCode, using: layout.assumingMemoryBound(
                to: UCKeyboardLayout.self
            ))
        }
    }

    private static func translate(
        keyCode: UInt32,
        using layout: UnsafePointer<UCKeyboardLayout>
    ) -> String? {
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let capacity = characters.count
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeys,
            capacity,
            &length,
            &characters
        )
        guard status == noErr, length > 0 else {
            return nil
        }
        return String(utf16CodeUnits: characters, count: length)
    }
}
