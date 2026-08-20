import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class PickerIntentTests: XCTestCase {
    private let home = PanelFixture.home

    func testTheThreeActionsFollowThePathBarTheMomentItIsOpen() async {
        let notes = home.appending(path: "notes")
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [
            home: [entry("code-studio", in: home), entry("notes", in: home)],
        ])
        model.browser.start()
        await settle(model)
        XCTAssertEqual(model.browser.selectedEntry?.url, studio)

        model.perform(.openPicker)
        model.picker.updateText("~/notes")
        await settlePicker(model)

        XCTAssertEqual(
            model.perform(.openInFinder),
            [.revealInFinder(notes, isDirectory: true), .dismiss],
            "回车打开的是路径栏里那一条，不是浏览区还选着的那一条"
        )
        XCTAssertEqual(model.perform(.copyPath), [.copyPath(notes), .dismiss])
    }

    func testLeavingThePathBarPutsTheBrowseAreaBackExactlyWhereItWas() async {
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [entry("MyQuickFinder", in: studio)],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)
        XCTAssertEqual(model.browser.directory, studio)

        model.perform(.openPicker)
        model.picker.updateText("~/")
        await settlePicker(model)
        XCTAssertEqual(model.perform(.exitPicker), [.focusPanel])

        XCTAssertEqual(model.browser.directory, studio, "退出路径栏不搬动浏览区")
        XCTAssertFalse(model.isPicking)
    }

    func testStarringInThePathBarActsOnTheHighlightedResultAndStaysPut() async {
        let notes = home.appending(path: "notes")
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)

        model.perform(.openPicker)
        model.picker.updateText("~/notes")
        await settlePicker(model)

        XCTAssertEqual(model.perform(.toggleFavorite), [], "收藏完焦点留在输入框")
        XCTAssertTrue(model.favorites.contains(url: notes))

        XCTAssertEqual(model.perform(.toggleFavorite), [])
        XCTAssertFalse(model.favorites.contains(url: notes))
    }

    func testJumpingToAFavoriteFromThePathBarClosesItFirst() async {
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [],
        ])
        model.browser.start()
        await settle(model)
        model.toggleFavoriteForSelection()

        model.perform(.openPicker)
        XCTAssertTrue(model.isPicking)

        XCTAssertEqual(model.perform(.activateFavorite(index: 0)), [.focusPanel])
        await settle(model)

        XCTAssertFalse(model.isPicking, "⌘1 从路径栏里也要先关掉路径栏")
        XCTAssertEqual(model.browser.directory, studio)
    }

    func testEscapeClearsThePathBarThenLeavesItEvenAfterEveryCharacterIsGone() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)

        model.perform(.openPicker)
        await settlePicker(model)
        XCTAssertFalse(model.picker.text.isEmpty, "打开时预填了当前路径")

        let typing = { model.inputContext(isTextFieldFocused: true) }
        XCTAssertEqual(
            PanelKeyMap.resolve(KeyChord(.escape), in: typing()),
            .intent(.clearPickerText),
            "第一下 ⎋ 是清空"
        )
        model.perform(.clearPickerText)
        await settlePicker(model)

        XCTAssertTrue(model.picker.text.isEmpty)
        XCTAssertEqual(
            PanelKeyMap.resolve(KeyChord(.escape), in: typing()),
            .intent(.exitPicker),
            "路径删光之后第二下 ⎋ 必须退出，不能变成一个死键"
        )

        XCTAssertEqual(model.perform(.exitPicker), [.focusPanel], "退出时要把焦点交还给面板")
        XCTAssertFalse(model.isPicking)
    }

    func testTheContextAlwaysReportsTheTextTheModelActuallyHolds() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)

        XCTAssertTrue(
            model.inputContext(isTextFieldFocused: false).isTextEmpty,
            "路径栏没开时文本就是空的"
        )
        XCTAssertEqual(model.inputContext(isTextFieldFocused: false).surface, .browse)

        model.perform(.openPicker)
        await settlePicker(model)
        XCTAssertFalse(model.inputContext(isTextFieldFocused: true).isTextEmpty)
        XCTAssertEqual(model.inputContext(isTextFieldFocused: true).surface, .picker)

        model.picker.updateText("")
        XCTAssertTrue(
            model.inputContext(isTextFieldFocused: true).isTextEmpty,
            "文本一变空，下一次取到的 context 就必须是空——不能落后一拍"
        )
    }

    func testCollapsingASelectionAsksTheFieldToParkTheCaretAtTheEnd() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        model.perform(.openPicker)
        await settlePicker(model)

        let before = model.picker.text
        XCTAssertEqual(model.perform(.collapseSelectionToEnd), [.moveCaretToPathEnd])
        XCTAssertEqual(model.picker.text, before, "只挪光标，不该动文本")
        XCTAssertTrue(model.isPicking, "也不该顺手退出路径栏")
    }

    func testPressingSlashThenRightArrowJustParksTheCaretAndNeverCompletes() async {
        let apps = home.appending(path: "Applications")
        let model = make(entries: [
            home: [entry("Applications", in: home)],
            apps: [entry("Claude Code URL Handler.app", in: apps)],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)

        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)
        let prefilled = model.picker.text

        let field = { model.inputContext(isTextFieldFocused: true, field: self.caretAtEnd(model)) }
        XCTAssertEqual(
            PanelKeyMap.resolve(KeyChord(.right), in: field()),
            .intent(.collapseSelectionToEnd),
            "刚按完 / 只按了一下 → ，不管字段编辑器说没说有选区，都不该补全"
        )

        XCTAssertEqual(model.perform(.collapseSelectionToEnd), [.moveCaretToPathEnd])
        XCTAssertEqual(model.picker.text, prefilled, "光标动了，路径一个字都不该变")

        XCTAssertEqual(
            PanelKeyMap.resolve(KeyChord(.right), in: field()),
            .intent(.completePath),
            "光标已经停在末尾之后，再按 → 才是补全"
        )
    }

    func testTypingClearsThePrefilledSelectionSoTheArrowCompletesAgain() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)
        XCTAssertTrue(model.picker.isPristine)

        model.picker.updateText("~/no")
        await settlePicker(model)

        XCTAssertFalse(model.picker.isPristine, "打过字之后就不再是预填状态")
        XCTAssertEqual(
            PanelKeyMap.resolve(
                KeyChord(.right),
                in: model.inputContext(isTextFieldFocused: true, field: caretAtEnd(model))
            ),
            .intent(.completePath)
        )
    }

    func testAFilterThatMatchesNothingLeavesEveryActionInert() async {
        let studio = home.appending(path: "code-studio")
        var listings: [URL: [DirectoryEntry]] = [
            home: [entry("code-studio", in: home)],
            studio: ["Atlas", "Journal"].map { entry($0, in: studio) },
        ]
        listings[studio.appending(path: "Atlas")] = []
        listings[studio.appending(path: "Journal")] = []
        let model = make(entries: listings)
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)

        model.perform(.openPicker, fromKeyboard: true)
        model.picker.updateText("download")
        await settlePicker(model)
        XCTAssertEqual(model.picker.entries.count, 0)

        XCTAssertFalse(model.hasActionTarget, "筛选没匹配到东西就是没有目标")
        XCTAssertEqual(model.perform(.openInFinder), [], "不该静默打开父目录，更不该顺手关掉面板")
        XCTAssertEqual(model.perform(.openInTerminal), [])
        XCTAssertEqual(model.perform(.copyPath), [])
        XCTAssertTrue(model.isPicking, "面板留着，让人改输入")
    }

    func testAnEmptyDirectoryYouActuallyPointedAtIsStillAValidTarget() async {
        let studio = home.appending(path: "code-studio")
        let empty = studio.appending(path: "Journal")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [entry("Journal", in: studio)],
            empty: [],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)

        model.perform(.openPicker, fromKeyboard: true)
        model.picker.updateText("~/code-studio/Journal/")
        await settlePicker(model)

        XCTAssertTrue(model.hasActionTarget, "空目录和「没匹配到」不是一回事")
        XCTAssertEqual(
            model.perform(.openInFinder),
            [.revealInFinder(empty, isDirectory: true), .dismiss]
        )
    }

    func testAPathThatDoesNotExistIsNotATargetEither() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        model.picker.updateText("~/nope/deeper/")
        await settlePicker(model)

        XCTAssertEqual(model.picker.state, .missing)
        XCTAssertFalse(model.hasActionTarget)
        XCTAssertEqual(model.perform(.openInFinder), [])
    }

    func testSlashThenReturnOpensTheDirectoryInTheBoxNotItsFirstChild() async {
        let studio = home.appending(path: "code-studio")
        let model = studioModel()
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)

        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)

        XCTAssertEqual(model.picker.entries.count, 3, "列表把这一层预览出来")
        XCTAssertNil(model.picker.highlightedIndex, "但一行都不该高亮——用户还没挑")
        XCTAssertEqual(
            model.perform(.openInFinder),
            [.revealInFinder(studio, isDirectory: true), .dismiss],
            "回车去的是框里写的那个目录，不是排在第一位的 Atlas"
        )
    }

    func testTheHighlightAppearsTheMomentTheUserActuallyPicksARow() async {
        let studio = home.appending(path: "code-studio")
        let model = studioModel()
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)

        model.perform(.moveSelection(1), fromKeyboard: true)
        XCTAssertEqual(model.picker.highlightedIndex, 0, "第一下 ↓ 进入列表顶端")
        XCTAssertEqual(model.actionTarget, studio.appending(path: "Atlas"))

        model.perform(.moveSelection(1), fromKeyboard: true)
        XCTAssertEqual(model.picker.highlightedIndex, 1)
        XCTAssertEqual(model.actionTarget, studio.appending(path: "Journal"))
    }

    func testTypingAFilterHighlightsTheTopMatchRightAway() async {
        let studio = home.appending(path: "code-studio")
        let model = studioModel()
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)

        model.picker.updateText("Atl")
        await settlePicker(model)

        XCTAssertEqual(model.picker.highlightedIndex, 0, "打了筛选就是在挑东西，立刻高亮头一条")
        XCTAssertEqual(model.actionTarget, studio.appending(path: "Atlas"))
    }

    func testStarringAResultLeavesYouFreeToKeepNavigating() async {
        let studio = home.appending(path: "code-studio")
        var listings: [URL: [DirectoryEntry]] = [
            home: [entry("code-studio", in: home)],
            studio: ["Atlas", "Beacon", "Cobalt"].map { entry($0, in: studio) },
        ]
        for name in ["Atlas", "Beacon", "Cobalt"] {
            listings[studio.appending(path: name)] = []
        }
        let model = make(entries: listings)
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)

        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)
        model.perform(.moveSelection(1), fromKeyboard: true)
        model.perform(.moveSelection(1), fromKeyboard: true)
        model.perform(.moveSelection(1), fromKeyboard: true)
        XCTAssertEqual(model.picker.highlightedIndex, 2)

        XCTAssertEqual(
            model.perform(.toggleFavorite, fromKeyboard: true),
            [],
            "收藏一条结果不该顺手把焦点从输入框抢走"
        )
        XCTAssertTrue(model.favorites.contains(url: studio.appending(path: "Cobalt")))

        model.perform(.moveSelection(-1), fromKeyboard: true)
        XCTAssertEqual(model.picker.highlightedIndex, 1, "收藏完还得能继续上下移动")

        XCTAssertEqual(model.perform(.activateFavorite(index: 0)), [.focusPanel], "⌘1 仍然有效")
        XCTAssertFalse(model.isPicking)
    }

    func testDismissingHelpHandsFocusBackToThePathBar() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)

        XCTAssertEqual(model.perform(.showHelp, fromKeyboard: true), [.focusPanel])
        XCTAssertEqual(
            model.perform(.hideHelp, fromKeyboard: true),
            [.focusPathField],
            "帮助层收起后路径栏还开着，焦点得还回输入框"
        )
    }

    func testOpeningThePathBarShowsTheListingImmediatelyWithNoLoadingFrame() async {
        let studio = home.appending(path: "code-studio")
        var listings: [URL: [DirectoryEntry]] = [
            home: [entry("code-studio", in: home)],
            studio: ["Atlas", "Journal"].map { entry($0, in: studio) },
        ]
        listings[studio.appending(path: "Atlas")] = []
        listings[studio.appending(path: "Journal")] = []
        let model = make(entries: listings)
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection, fromKeyboard: true)
        await settle(model)

        model.perform(.openPicker, fromKeyboard: true)

        XCTAssertEqual(
            model.picker.entries.map(\.name),
            ["Atlas", "Journal"],
            "浏览区手上已经有这一层了，按 / 不该先空一帧再异步重读一遍"
        )
        XCTAssertNil(model.picker.pendingLoad, "也不该为此再起一个读取任务")
    }

    func testADirectoryTheBrowseAreaCouldNotReadIsNotUsedAsASeed() async {
        let model = make(entries: [:], failing: [home: denialError()])
        model.browser.start()
        await settle(model)
        XCTAssertTrue(model.browser.isDenied)

        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)

        XCTAssertEqual(model.picker.state, .denied, "读不到就该如实说读不到，不能拿空清单冒充")
    }

    func testCaretAtEndIsJudgedAgainstTheModelsTextNotTheEditorsContents() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        model.picker.updateText("~/no")
        await settlePicker(model)

        let typed = model.picker.text.count
        let atEnd = PathFieldFacts(selectionLength: 0, caretLocation: typed, isComposing: false)
        let inside = PathFieldFacts(
            selectionLength: 0,
            caretLocation: typed - 1,
            isComposing: false
        )
        let pastGhost = PathFieldFacts(
            selectionLength: 0,
            caretLocation: typed + 12,
            isComposing: false
        )

        XCTAssertTrue(model.inputContext(isTextFieldFocused: true, field: atEnd).isCaretAtEnd)
        XCTAssertFalse(model.inputContext(isTextFieldFocused: true, field: inside).isCaretAtEnd)
        XCTAssertTrue(
            model.inputContext(isTextFieldFocused: true, field: pastGhost).isCaretAtEnd,
            "灰色补全提示后面也算末尾——长度由模型持有的文本决定，不靠视图记的 ghost 反推"
        )
    }

    func testFieldFactsOnlyCarryWhatOnlyTheEditorKnows() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)

        let selecting = PathFieldFacts(selectionLength: 4, caretLocation: 0, isComposing: false)
        let composing = PathFieldFacts(selectionLength: 0, caretLocation: 2, isComposing: true)

        XCTAssertTrue(model.inputContext(
            isTextFieldFocused: true,
            field: selecting
        ).hasTextSelection)
        XCTAssertTrue(model.inputContext(
            isTextFieldFocused: true,
            field: composing
        ).isComposingText)
        XCTAssertEqual(
            model.inputContext(isTextFieldFocused: true, field: selecting).isTextEmpty,
            model.picker.text.isEmpty,
            "文本是否为空一律问模型，视图报什么都不影响"
        )
    }

    private func caretAtEnd(_ model: PanelModel) -> PathFieldFacts {
        PathFieldFacts(
            selectionLength: 0,
            caretLocation: model.picker.text.count,
            isComposing: false
        )
    }

    private func studioModel() -> PanelModel {
        let studio = home.appending(path: "code-studio")
        var listings: [URL: [DirectoryEntry]] = [
            home: [entry("code-studio", in: home)],
            studio: ["Atlas", "Journal", "MyQuickFinder"].map { entry($0, in: studio) },
        ]
        for name in ["Atlas", "Journal", "MyQuickFinder"] {
            listings[studio.appending(path: name)] = []
        }
        return make(entries: listings)
    }

    private func entry(_ name: String, in parent: URL, isDirectory: Bool = true) -> DirectoryEntry {
        PanelFixture.entry(name, in: parent, isDirectory: isDirectory)
    }

    private func denialError() -> Error {
        PanelFixture.denialError()
    }

    private func make(
        entries: [URL: [DirectoryEntry]],
        failing: [URL: Error] = [:]
    ) -> PanelModel {
        PanelFixture.make(entries: entries, failing: failing)
    }

    private func settle(_ model: PanelModel) async {
        await PanelFixture.settle(model)
    }

    private func settlePicker(_ model: PanelModel) async {
        await PanelFixture.settlePicker(model)
    }
}
