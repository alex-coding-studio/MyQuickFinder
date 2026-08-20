import Foundation
import XCTest
@testable import MyQuickFinderKit

final class KeyChordModifierTests: XCTestCase {
    private enum AppKitRaw {
        static let capsLock: UInt = 65536
        static let shift: UInt = 131_072
        static let control: UInt = 262_144
        static let option: UInt = 524_288
        static let command: UInt = 1_048_576
        static let numericPad: UInt = 2_097_152
        static let function: UInt = 8_388_608
    }

    private enum SwiftUIRaw {
        static let capsLock = 1
        static let shift = 2
        static let control = 4
        static let option = 8
        static let command = 16
        static let numericPad = 32
    }

    private static let appKitLayout = KeyChord.Modifiers.Layout(
        command: Int(AppKitRaw.command),
        option: Int(AppKitRaw.option),
        shift: Int(AppKitRaw.shift),
        control: Int(AppKitRaw.control)
    )

    private static let swiftUILayout = KeyChord.Modifiers.Layout(
        command: SwiftUIRaw.command,
        option: SwiftUIRaw.option,
        shift: SwiftUIRaw.shift,
        control: SwiftUIRaw.control
    )

    func testKeysTheUserNeverPressedAreDroppedFromBothPlatforms() {
        XCTAssertEqual(swiftUI(SwiftUIRaw.numericPad), [], "方向键自带的 numericPad")
        XCTAssertEqual(swiftUI(SwiftUIRaw.capsLock), [], "大写锁定")
        XCTAssertEqual(appKit(AppKitRaw.numericPad), [], "AppKit 的 numericPad")
        XCTAssertEqual(appKit(AppKitRaw.function), [], "功能键位")
        XCTAssertEqual(appKit(AppKitRaw.capsLock), [], "AppKit 的大写锁定")
    }

    func testRealModifiersSurviveAlongsideTheNoiseBits() {
        XCTAssertEqual(
            swiftUI(SwiftUIRaw.command | SwiftUIRaw.numericPad),
            .command
        )
        XCTAssertEqual(
            appKit(AppKitRaw.command | AppKitRaw.option | AppKitRaw.numericPad),
            [.command, .option]
        )
        XCTAssertEqual(
            swiftUI(SwiftUIRaw.shift | SwiftUIRaw.control | SwiftUIRaw.capsLock),
            [.shift, .control]
        )
    }

    func testAnArrowKeyResolvesTheSameWithOrWithoutTheNumericPadBit() {
        let context = PanelInputContext(surface: .browse)
        let noisy = KeyChord(.right, swiftUI(SwiftUIRaw.numericPad))
        let clean = KeyChord(.right)

        XCTAssertEqual(noisy, clean)
        XCTAssertEqual(
            PanelKeyMap.resolve(noisy, in: context),
            PanelKeyMap.resolve(clean, in: context)
        )
        XCTAssertEqual(PanelKeyMap.resolve(noisy, in: context), .intent(.enterSelection))
    }

    func testTheFieldEditorArrowAlsoSurvivesTheNumericPadBit() {
        let context = PanelInputContext(surface: .picker, isTextFieldFocused: true)
        let noisy = KeyChord(.right, appKit(AppKitRaw.numericPad))

        XCTAssertEqual(PanelKeyMap.resolve(noisy, in: context), .intent(.completePath))
    }

    private func appKit(_ raw: UInt) -> KeyChord.Modifiers {
        KeyChord.Modifiers.decoding(Int(bitPattern: raw), using: Self.appKitLayout)
    }

    private func swiftUI(_ raw: Int) -> KeyChord.Modifiers {
        KeyChord.Modifiers.decoding(raw, using: Self.swiftUILayout)
    }
}
