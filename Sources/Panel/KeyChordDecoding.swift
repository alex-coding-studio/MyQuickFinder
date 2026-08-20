import AppKit
import MyQuickFinderKit
import SwiftUI

extension KeyChord.Modifiers {
    static let appKitLayout = Layout(
        command: Int(NSEvent.ModifierFlags.command.rawValue),
        option: Int(NSEvent.ModifierFlags.option.rawValue),
        shift: Int(NSEvent.ModifierFlags.shift.rawValue),
        control: Int(NSEvent.ModifierFlags.control.rawValue)
    )

    static let swiftUILayout = Layout(
        command: EventModifiers.command.rawValue,
        option: EventModifiers.option.rawValue,
        shift: EventModifiers.shift.rawValue,
        control: EventModifiers.control.rawValue
    )

    static func appKit(_ raw: UInt) -> KeyChord.Modifiers {
        decoding(Int(bitPattern: raw), using: appKitLayout)
    }

    static func swiftUI(_ raw: Int) -> KeyChord.Modifiers {
        decoding(raw, using: swiftUILayout)
    }
}
