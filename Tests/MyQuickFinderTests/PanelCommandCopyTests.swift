import MyQuickFinderKit
import XCTest
@testable import MyQuickFinder

final class PanelCommandCopyTests: XCTestCase {
    func testTheFavouriteCapIsBuiltFromTheRealShortcutChords() {
        let capacity = FavoriteList.shortcutCapacity
        let first = FavoriteList.shortcutChord(at: 0)
        let last = FavoriteList.shortcutChord(at: capacity - 1)

        XCTAssertNotNil(first)
        XCTAssertNotNil(last)
        XCTAssertEqual(PanelCommandCopy.keyCap(.activateFavorite, in: .default), "⌘1–9 ⌘0")
        XCTAssertEqual(PanelCommandCopy.settingsCap(.activateFavorite, in: .default), "⌘ 1–9   ⌘ 0")
        XCTAssertTrue(
            PanelCommandCopy.settingsCap(.activateFavorite, in: .default)
                .hasPrefix(FavoriteList.shortcut(at: 0) ?? ""),
            "文案的第一段必须就是收藏栏第一项真正打出来的快捷键"
        )
        XCTAssertTrue(
            PanelCommandCopy.settingsCap(.activateFavorite, in: .default)
                .hasSuffix(FavoriteList.shortcut(at: capacity - 1) ?? ""),
            "最后一段必须就是第 10 项真正打出来的快捷键"
        )
    }

    func testTheMoveCapFollowsTheKeyMapInsteadOfAFrozenString() {
        XCTAssertEqual(PanelCommandCopy.keyCap(.moveSelectionUp, in: .default), "↑ ↓")
        XCTAssertEqual(PanelCommandCopy.settingsCap(.moveSelectionUp, in: .default), "↑   ↓")

        let rebound = KeyBindings.default
            .rebinding(.moveSelectionUp, to: KeyChord(.character("k")))
            .rebinding(.moveSelectionDown, to: KeyChord(.character("j")))

        XCTAssertEqual(PanelCommandCopy.keyCap(.moveSelectionUp, in: rebound), "K J")
        XCTAssertEqual(PanelCommandCopy.settingsCap(.moveSelectionUp, in: rebound), "K   J")
    }

    func testAnOrdinaryCommandStillReadsStraightFromTheBindings() {
        XCTAssertEqual(PanelCommandCopy.keyCap(.copyPath, in: .default), "⌘C")
        XCTAssertEqual(PanelCommandCopy.settingsCap(.copyPath, in: .default), "⌘ C")
        XCTAssertEqual(
            PanelCommandCopy.keyCap(.enterSelection, in: .default),
            KeyChordFormatter.display(KeyBindings.default.chords(for: .enterSelection))
        )
    }

    func testEveryHelpRowHasSomethingToShow() {
        for command in PanelCommandCopy.helpOrder {
            XCTAssertFalse(
                PanelCommandCopy.settingsCap(command, in: .default).isEmpty,
                "\(command.rawValue) 在帮助页会渲染成一行空白"
            )
            XCTAssertFalse(PanelCommandCopy.title(command).isEmpty)
        }
    }
}
