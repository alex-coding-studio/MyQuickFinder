import Foundation
import XCTest
@testable import MyQuickFinderKit

final class KeyBindingsTests: XCTestCase {
    private static let disambiguatedByContext: Set<PanelCommand> = [
        .enterSelection,
        .completePath,
        .switchZone,
    ]

    func testEveryCommandHasAtLeastOneDefaultChord() {
        for command in PanelCommand.allCases where command != .activateFavorite {
            XCTAssertFalse(
                KeyBindings.default.chords(for: command).isEmpty,
                "\(command) 没有默认键位——面板上就没法显示它，设置页也列不出来"
            )
        }
    }

    func testNoTwoCommandsShareAChordUnlessContextTellsThemApart() {
        var seen = [KeyChord: PanelCommand]()
        for command in PanelCommand.allCases {
            for chord in KeyBindings.default.chords(for: command) {
                if let owner = seen[chord], owner != command {
                    XCTAssertTrue(
                        Self.disambiguatedByContext.contains(owner)
                            && Self.disambiguatedByContext.contains(command),
                        "\(KeyChordFormatter.display(chord)) 被 \(owner) 与 \(command) 同时占用，"
                            + "而这两个命令并不靠上下文区分"
                    )
                }
                seen[chord] = command
            }
        }
    }

    func testRebindingReplacesOnlyThatCommand() {
        let rebound = KeyBindings.default.rebinding(
            .copyPath,
            to: KeyChord(.character("y"), .command)
        )

        XCTAssertEqual(rebound.chord(for: .copyPath), KeyChord(.character("y"), .command))
        XCTAssertEqual(
            rebound.chord(for: .toggleFavorite),
            KeyBindings.default.chord(for: .toggleFavorite),
            "改一条不该动到别的"
        )
    }

    func testConflictNamesWhoAlreadyOwnsTheChord() throws {
        let taken = try XCTUnwrap(KeyBindings.default.chord(for: .toggleFavorite))

        XCTAssertEqual(
            KeyBindings.default.conflict(for: taken, ignoring: .copyPath),
            .toggleFavorite
        )
        XCTAssertNil(
            KeyBindings.default.conflict(for: taken, ignoring: .toggleFavorite),
            "它自己占着不算冲突"
        )
        XCTAssertNil(
            KeyBindings.default.conflict(
                for: KeyChord(.character("y"), .command),
                ignoring: .copyPath
            )
        )
    }

    func testRebindingActuallyChangesWhatTheKeyDoes() {
        let context = PanelInputContext(surface: .browse)
        let rebound = KeyBindings.default.rebinding(
            .copyPath,
            to: KeyChord(.character("y"), .command)
        )

        XCTAssertEqual(
            PanelKeyMap.resolve(
                KeyChord(.character("y"), .command),
                in: context,
                bindings: rebound
            ),
            .intent(.copyPath),
            "换了键位，新键位就该生效"
        )
        XCTAssertEqual(
            PanelKeyMap.resolve(
                KeyChord(.character("c"), .command),
                in: context,
                bindings: rebound
            ),
            .pass,
            "旧键位就该失效，而不是两个都能用"
        )
    }

    func testKeysThatCarryMacOSSemanticsStayFixed() {
        for command in [
            PanelCommand.moveSelectionUp,
            .moveSelectionDown,
            .enterSelection,
            .goToParent,
            .switchZone,
            .completePath,
            .dismissPanel,
        ] {
            XCTAssertFalse(
                command.isCustomizable,
                "\(command) 在 macOS 上语义固定，放开会让面板变得不可预期"
            )
        }
    }

    func testTheCoreLoopsOwnKeysStayFixed() {
        for command in [
            PanelCommand.openInFinder,
            .openInTerminal,
            .copyPath,
            .openPicker,
            .activateFavorite,
        ] {
            XCTAssertFalse(
                command.isCustomizable,
                "\(command) 是核心闭环的入口或动作，键位是产品的一部分，不放开"
            )
        }
    }

    func testOnlyTheAuxiliaryOperationsAreOpenForRebinding() {
        XCTAssertEqual(
            Set(PanelCommand.allCases.filter(\.isCustomizable)),
            [.toggleFavorite, .toggleHidden, .openAncestors, .showHelp]
        )
    }

    func testEveryCustomizableCommandAlreadyCarriesAModifier() {
        for command in PanelCommand.allCases where command.isCustomizable {
            let chords = KeyBindings.default.chords(for: command)
            for chord in chords {
                XCTAssertFalse(
                    chord.modifiers.isEmpty,
                    "\(command) 的默认键位没有修饰键——裸键录制会和路径栏里的打字打架"
                )
            }
        }
    }

    func testEveryCommandIsEitherFixedOrCustomizableWithNothingLeftOut() {
        let fixed = PanelCommand.allCases.filter { !$0.isCustomizable }
        let customizable = PanelCommand.allCases.filter(\.isCustomizable)

        XCTAssertEqual(
            fixed.count + customizable.count,
            PanelCommand.allCases.count,
            "每个命令都要明确落在两边之一——设置页按这个分列，漏一个就有键位在界面上消失"
        )
        XCTAssertFalse(customizable.isEmpty)
        XCTAssertFalse(fixed.isEmpty)
    }

    func testSettingsRenderChordsWithBreathingRoom() {
        XCTAssertEqual(KeyChordFormatter.spaced(KeyChord(.up, [.command, .option])), "⌥ ⌘ ↑")
        XCTAssertEqual(
            KeyChordFormatter.spaced(KeyChord(.character("."), [.command, .shift])),
            "⇧ ⌘ ."
        )
        XCTAssertEqual(
            KeyChordFormatter.display(KeyChord(.up, [.command, .option])),
            "⌥⌘↑",
            "面板里的内联提示仍然紧凑——面包屑和药丸那儿是真挤"
        )
    }

    func testChordsRenderTheWayMacUsersReadThem() {
        XCTAssertEqual(KeyChordFormatter.display(KeyChord(.character("d"), .command)), "⌘D")
        XCTAssertEqual(
            KeyChordFormatter.display(KeyChord(.character("."), [.command, .shift])),
            "⇧⌘."
        )
        XCTAssertEqual(KeyChordFormatter.display(KeyChord(.up, [.command, .option])), "⌥⌘↑")
        XCTAssertEqual(KeyChordFormatter.display(KeyChord(.escape)), "⎋")
        XCTAssertEqual(
            KeyChordFormatter.display(KeyBindings.default.chords(for: .goToParent)),
            "← / ⌘↑"
        )
    }
}
