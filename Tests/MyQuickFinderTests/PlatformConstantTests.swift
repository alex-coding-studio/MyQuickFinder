import AppKit
import Carbon.HIToolbox
import MyQuickFinderKit
import SwiftUI
import XCTest
@testable import MyQuickFinder

final class PlatformConstantTests: XCTestCase {
    func testAppKitNoiseBitsNeverReachTheKeyMap() {
        let noisy = NSEvent.ModifierFlags([.command, .option, .numericPad, .capsLock, .function])

        XCTAssertEqual(KeyChord.Modifiers.appKit(noisy.rawValue), [.command, .option])
        XCTAssertEqual(KeyChord.Modifiers.appKit(NSEvent.ModifierFlags.capsLock.rawValue), [])
        XCTAssertEqual(KeyChord.Modifiers.appKit(NSEvent.ModifierFlags.numericPad.rawValue), [])
    }

    func testEveryAppKitModifierMapsToItsOwnChordModifier() {
        XCTAssertEqual(KeyChord.Modifiers.appKit(NSEvent.ModifierFlags.command.rawValue), .command)
        XCTAssertEqual(KeyChord.Modifiers.appKit(NSEvent.ModifierFlags.option.rawValue), .option)
        XCTAssertEqual(KeyChord.Modifiers.appKit(NSEvent.ModifierFlags.shift.rawValue), .shift)
        XCTAssertEqual(KeyChord.Modifiers.appKit(NSEvent.ModifierFlags.control.rawValue), .control)
    }

    func testSwiftUINoiseBitsNeverReachTheKeyMap() {
        let noisy = EventModifiers([.command, .shift, .numericPad, .capsLock])

        XCTAssertEqual(KeyChord.Modifiers.swiftUI(noisy.rawValue), [.command, .shift])
        XCTAssertEqual(KeyChord.Modifiers.swiftUI(EventModifiers.numericPad.rawValue), [])
        XCTAssertEqual(KeyChord.Modifiers.swiftUI(EventModifiers.capsLock.rawValue), [])
    }

    func testEverySwiftUIModifierMapsToItsOwnChordModifier() {
        XCTAssertEqual(KeyChord.Modifiers.swiftUI(EventModifiers.command.rawValue), .command)
        XCTAssertEqual(KeyChord.Modifiers.swiftUI(EventModifiers.option.rawValue), .option)
        XCTAssertEqual(KeyChord.Modifiers.swiftUI(EventModifiers.shift.rawValue), .shift)
        XCTAssertEqual(KeyChord.Modifiers.swiftUI(EventModifiers.control.rawValue), .control)
    }

    func testTheDefaultHotKeyIsOptionSpaceInCarbonTerms() {
        XCTAssertEqual(HotKeyBinding.optionSpace.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(HotKeyBinding.optionSpace.carbonModifiers, UInt32(optionKey))
        XCTAssertTrue(HotKeyBinding.optionSpace.hasModifier)
    }

    func testTheHotKeyLabelIsDerivedFromTheStoredKeyCodeAndModifiers() {
        let escape = HotKeyBinding(
            keyCode: UInt32(kVK_Escape),
            carbonModifiers: UInt32(controlKey) | UInt32(shiftKey)
        )

        XCTAssertEqual(HotKeyLabel.text(for: escape), "⌃⇧⎋")
        XCTAssertEqual(HotKeyLabel.keyName(for: UInt32(kVK_LeftArrow)), "←")
        XCTAssertEqual(
            HotKeyLabel.text(for: .optionSpace),
            "⌥" + HotKeyLabel.keyName(for: UInt32(kVK_Space))
        )
    }

    func testAPrintableKeyIsReadFromTheCurrentKeyboardLayout() {
        let letter = HotKeyLabel.keyName(for: UInt32(kVK_ANSI_C))

        XCTAssertEqual(letter.count, 1)
        XCTAssertEqual(letter, letter.uppercased())
    }

    func testTheSpaceKeyNameComesFromTheCatalogRatherThanTheKey() {
        let name = HotKeyLabel.keyName(for: UInt32(kVK_Space))

        XCTAssertFalse(name.isEmpty)
        XCTAssertNotEqual(name, "key.space")
    }

    func testARecordedComboIsTranslatedIntoCarbonModifiers() {
        XCTAssertEqual(
            HotKeyTranslation.carbonModifiers(from: [.command, .option]),
            UInt32(cmdKey) | UInt32(optionKey)
        )
        XCTAssertEqual(
            HotKeyTranslation.carbonModifiers(from: [.control, .shift]),
            UInt32(controlKey) | UInt32(shiftKey)
        )
        XCTAssertEqual(HotKeyTranslation.carbonModifiers(from: [.capsLock]), 0)
    }
}
