import Foundation
import XCTest
@testable import MyQuickFinderKit

final class PanelKeyMapTests: XCTestCase {
    func testSlashIsASeparatorWhileTypingAndAnEntryPointEverywhereElse() {
        check(KeyChord(.character("/")), typing(), .pass, "输入框有焦点时 / 就是斜杠")
        check(
            KeyChord(.character("/")),
            pickerWithoutFocus(),
            .intent(.refocusPathField),
            "路径栏开着但焦点不在输入框时，/ 是回到输入框"
        )
        check(KeyChord(.character("/")), browse(), .intent(.openPicker), "浏览区按 / 打开路径栏")
        check(
            KeyChord(.character("/")),
            browse(showsHelp: true),
            .intent(.openPicker),
            "帮助层浮着时 / 仍然优先开路径栏，不是先关帮助"
        )
    }

    func testCommandShortcutsReachBothSurfaces() {
        for context in [browse(), typing()] {
            check(KeyChord(.character("d"), .command), context, .intent(.toggleFavorite), "⌘D")
            check(KeyChord(.character("/"), .command), context, .intent(.showHelp), "⌘/")
            check(KeyChord(.return, .command), context, .intent(.openInTerminal), "⌘↩")
            check(KeyChord(.character("c"), .command), context, .intent(.copyPath), "⌘C")
            check(KeyChord(.return), context, .intent(.openInFinder), "↩")
        }
    }

    func testFavoriteDigitsMapOneThroughNineThenZero() {
        for context in [browse(), typing()] {
            for digit in 1 ... 9 {
                check(
                    KeyChord(.character(Character("\(digit)")), .command),
                    context,
                    .intent(.activateFavorite(index: digit - 1)),
                    "⌘\(digit)"
                )
            }
            check(
                KeyChord(.character("0"), .command),
                context,
                .intent(.activateFavorite(index: FavoriteList.shortcutCapacity - 1)),
                "⌘0 是第 10 个"
            )
        }
    }

    func testRightArrowOnlyCompletesWhenTheCaretIsAloneAtTheEnd() {
        check(KeyChord(.right), typing(), .intent(.completePath), "光标在末尾时 → 补全")
        check(
            KeyChord(.right),
            typing(hasTextSelection: true),
            .intent(.collapseSelectionToEnd),
            "全选时 → 是把光标送到最右边，不是补全"
        )
        check(
            KeyChord(.right),
            typing(hasTextSelection: true, isCaretAtEnd: false),
            .intent(.collapseSelectionToEnd),
            "部分选中也一样送到最右边——不是停在选区的右边缘"
        )
        check(KeyChord(.right), typing(isCaretAtEnd: false), .pass, "无选区且光标在中间时 → 只是移动光标")
        check(KeyChord(.right), browse(), .intent(.enterSelection), "浏览区 → 是进入")
    }

    func testEscapeMeansSomethingDifferentInEveryContext() {
        check(KeyChord(.escape), typing(isTextEmpty: false), .intent(.clearPickerText), "先清空")
        check(KeyChord(.escape), typing(isTextEmpty: true), .intent(.exitPicker), "空了再退出")
        check(
            KeyChord(.escape),
            pickerWithoutFocus(),
            .intent(.clearPickerText),
            "焦点在不在输入框，⎋ 都是同一条两段式规则"
        )
        check(KeyChord(.escape), browse(showsHelp: true), .intent(.hideHelp), "先收帮助层")
        check(KeyChord(.escape), browse(), .intent(.dismissPanel), "最后才关面板")
    }

    func testTheAncestorMenuOwnsEveryKeyWhileItIsOpen() {
        let open = browse(showsAncestors: true)
        check(KeyChord(.up), open, .intent(.moveAncestorSelection(-1)), "↑")
        check(KeyChord(.down), open, .intent(.moveAncestorSelection(1)), "↓")
        check(KeyChord(.return), open, .intent(.confirmAncestor), "↩")
        check(KeyChord(.escape), open, .intent(.closeAncestors), "⎋")
        check(KeyChord(.tab), open, .swallow, "其余键被吞掉，不穿透到下面")
        check(KeyChord(.character("x")), open, .swallow, "字母也吞掉")
        check(KeyChord(.character("d"), .command), open, .swallow, "⌘D 也不穿透")

        let openOverPicker = PanelInputContext(
            surface: .picker,
            showsAncestors: true,
            isTextFieldFocused: true
        )
        check(KeyChord(.up), openOverPicker, .intent(.moveAncestorSelection(-1)), "祖先菜单优先于路径栏")
    }

    func testBrowseOnlyCommandChordsDoNotLeakIntoThePicker() {
        check(KeyChord(.up, [.command, .option]), browse(), .intent(.openAncestors), "⌥⌘↑")
        check(
            KeyChord(.character("."), [.command, .shift]),
            browse(),
            .intent(.toggleHidden),
            "⇧⌘."
        )
        check(KeyChord(.up, .command), browse(), .intent(.goToParent), "⌘↑")
        check(KeyChord(.down, .command), browse(), .intent(.enterSelection), "⌘↓")

        check(KeyChord(.up, [.command, .option]), typing(), .pass, "路径栏里 ⌥⌘↑ 不抢")
        check(KeyChord(.character("."), [.command, .shift]), typing(), .pass, "路径栏里 ⇧⌘. 不抢")
        check(KeyChord(.up, .command), typing(), .pass, "路径栏里 ⌘↑ 留给文本编辑")
    }

    func testPlainNavigationInEachSurface() {
        check(KeyChord(.up), browse(), .intent(.moveSelection(-1)), "浏览区 ↑")
        check(KeyChord(.down), browse(), .intent(.moveSelection(1)), "浏览区 ↓")
        check(KeyChord(.left), browse(), .intent(.goToParent), "浏览区 ←")
        check(KeyChord(.tab), browse(), .intent(.switchZone), "⇥ 换区")

        check(KeyChord(.up), typing(), .intent(.moveSelection(-1)), "路径栏 ↑ 选结果")
        check(KeyChord(.down), typing(), .intent(.moveSelection(1)), "路径栏 ↓ 选结果")
        check(KeyChord(.tab), typing(), .intent(.completePath), "路径栏 ⇥ 是补全，不是换区")
        check(KeyChord(.character("a")), typing(), .pass, "普通字符交给输入框")
    }

    func testAnyKeyDismissesTheHelpOverlay() {
        check(KeyChord(.tab), browse(showsHelp: true), .intent(.hideHelp), "帮助层浮着时任意键先收它")
        check(KeyChord(.character("x")), browse(showsHelp: true), .intent(.hideHelp), "字母也收")
        check(
            KeyChord(.escape),
            pickerWithoutFocus(showsHelp: true),
            .intent(.hideHelp),
            "路径栏上浮着帮助层时也一样"
        )
    }

    func testEveryKeyBelongsToTheInputMethodWhileItIsComposing() {
        let composing = PanelInputContext(
            surface: .picker,
            isTextFieldFocused: true,
            isComposingText: true
        )
        for chord in [
            KeyChord(.return),
            KeyChord(.escape),
            KeyChord(.up),
            KeyChord(.down),
            KeyChord(.right),
            KeyChord(.tab),
            KeyChord(.character("d"), .command),
            KeyChord(.character("1"), .command),
        ] {
            check(chord, composing, .pass, "组字期间 \(chord.key) 属于输入法，面板不许抢")
        }
    }

    func testTheSameKeysComeBackTheMomentCompositionEnds() {
        let settled = PanelInputContext(surface: .picker, isTextFieldFocused: true)

        check(KeyChord(.return), settled, .intent(.openInFinder), "上屏之后回车才是打开")
        check(KeyChord(.down), settled, .intent(.moveSelection(1)), "↓ 也回来了")
        check(
            KeyChord(.character("d"), .command),
            settled,
            .intent(.toggleFavorite),
            "⌘D 也回来了"
        )
    }

    func testCharacterCaseIsNormalizedSoCapsLockCannotBreakShortcuts() {
        XCTAssertEqual(KeyChord(.character("D")), KeyChord(.character("d")))
        check(KeyChord(.character("D"), .command), browse(), .intent(.toggleFavorite), "⌘⇪D 仍是收藏")
        check(KeyChord(.character("C"), .command), browse(), .intent(.copyPath), "⌘⇪C 仍是复制")
    }

    func testOnlyNavigationIntentsSurviveAKeyBeingHeldDown() {
        for intent in [
            PanelIntent.moveSelection(1),
            .moveAncestorSelection(-1),
            .enterSelection,
            .goToParent,
        ] {
            XCTAssertTrue(intent.allowsRepeat, "\(intent) 长按应该连发")
        }
        for intent in [
            PanelIntent.toggleFavorite,
            .openPicker,
            .exitPicker,
            .dismissPanel,
            .copyPath,
            .openInFinder,
            .openInTerminal,
            .showHelp,
            .activateFavorite(index: 0),
            .toggleHidden,
            .confirmAncestor,
        ] {
            XCTAssertFalse(intent.allowsRepeat, "\(intent) 长按不该连发")
        }
    }

    private func browse(
        showsHelp: Bool = false,
        showsAncestors: Bool = false
    ) -> PanelInputContext {
        PanelInputContext(surface: .browse, showsHelp: showsHelp, showsAncestors: showsAncestors)
    }

    private func typing(
        isTextEmpty: Bool = false,
        hasTextSelection: Bool = false,
        isCaretAtEnd: Bool = true
    ) -> PanelInputContext {
        PanelInputContext(
            surface: .picker,
            isTextFieldFocused: true,
            hasTextSelection: hasTextSelection,
            isCaretAtEnd: isCaretAtEnd,
            isTextEmpty: isTextEmpty
        )
    }

    private func pickerWithoutFocus(showsHelp: Bool = false) -> PanelInputContext {
        PanelInputContext(surface: .picker, showsHelp: showsHelp, isTextFieldFocused: false)
    }

    private func check(
        _ chord: KeyChord,
        _ context: PanelInputContext,
        _ expected: PanelKeyResolution,
        _ message: String,
        line: UInt = #line
    ) {
        XCTAssertEqual(PanelKeyMap.resolve(chord, in: context), expected, message, line: line)
    }
}
