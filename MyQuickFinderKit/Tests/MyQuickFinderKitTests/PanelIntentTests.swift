import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class PanelIntentTests: XCTestCase {
    private let home = PanelFixture.home

    func testTheThreeActionsAimAtTheBrowseSelectionWhileThePickerIsClosed() async {
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [home: [entry("code-studio", in: home)]])
        model.browser.start()
        await settle(model)

        XCTAssertEqual(model.perform(.openInFinder), [
            .revealInFinder(studio, isDirectory: true),
            .dismiss,
        ])
        XCTAssertEqual(model.perform(.openInTerminal), [.openInTerminal(studio), .dismiss])
        XCTAssertEqual(model.perform(.copyPath), [.copyPath(studio), .dismiss])
    }

    func testADeniedDirectoryStillOffersFinderButNotTerminalOrCopy() async {
        let model = make(entries: [:], failing: [home: denialError()])
        model.browser.start()
        await settle(model)
        XCTAssertTrue(model.browser.isDenied)

        XCTAssertEqual(
            model.perform(.openInFinder),
            [.revealInFinder(home, isDirectory: true), .dismiss],
            "读不到也要留「仍在 Finder 打开」这条退路"
        )
        XCTAssertEqual(model.perform(.openInTerminal), [], "读不到就不该假装能在终端打开")
        XCTAssertEqual(model.perform(.copyPath), [], "读不到就不该复制一个假路径")
    }

    func testStarringInTheFavoritesZoneRemovesThatFavoriteRatherThanJumpingAway() async {
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [],
        ])
        model.browser.start()
        await settle(model)
        model.toggleFavoriteForSelection()
        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)
        XCTAssertEqual(model.zone, .favorites)

        model.perform(.toggleFavorite)
        await settle(model)

        XCTAssertTrue(model.favorites.isEmpty, "收藏栏上按 ⌘D 是取消这一条")
        XCTAssertEqual(model.browser.directory, home, "最后一条没了，浏览区回到根")
    }

    func testArrowKeysLandOnWhicheverSurfaceIsCurrentlyInCharge() async {
        let model = make(entries: [
            home: [entry("a", in: home), entry("b", in: home)],
        ])
        model.browser.start()
        await settle(model)

        model.perform(.moveSelection(1))
        XCTAssertEqual(model.browser.selectionIndex, 1, "列表区 ↓ 走浏览区")

        model.toggleFavoriteForSelection()
        model.perform(.switchZone)
        XCTAssertEqual(model.zone, .favorites)

        model.perform(.openPicker)
        model.picker.updateText("~/")
        await settlePicker(model)
        model.perform(.moveSelection(1))
        XCTAssertEqual(model.picker.highlightedIndex, 0, "路径栏开着时 ↓ 走路径栏，第一下进列表顶端")
        XCTAssertEqual(model.browser.selectionIndex, 1, "浏览区的选中不受影响")
    }

    func testFocusEffectsAccompanyEverySurfaceChange() async {
        let model = make(entries: [home: [entry("a", in: home)]])
        model.browser.start()
        await settle(model)

        XCTAssertEqual(model.perform(.openPicker), [.focusPathField])
        XCTAssertEqual(model.perform(.refocusPathField), [.focusPathField])
        XCTAssertEqual(model.perform(.showHelp), [.focusPanel], "帮助层浮出后输入框要交出焦点")
        XCTAssertEqual(
            model.perform(.hideHelp),
            [.focusPathField],
            "帮助层收起时路径栏还开着，焦点得还回输入框"
        )
        XCTAssertEqual(model.perform(.exitPicker), [.focusPanel])
        XCTAssertEqual(model.perform(.hideHelp), [], "路径栏关了就没地方还")
        XCTAssertEqual(model.perform(.dismissPanel), [.dismiss])
    }

    func testTheFirstKeyPressEngagesTheKeyboardAndItNeverDisengages() async {
        let model = make(entries: [home: [entry("a", in: home), entry("b", in: home)]])
        model.browser.start()
        await settle(model)
        XCTAssertFalse(model.browser.keyboardEngaged, "鼠标唤起后还没碰键盘")

        model.perform(.moveSelection(1))
        XCTAssertTrue(model.browser.keyboardEngaged, "第一次按键就转成强调色")

        model.browser.selectRow(0)
        XCTAssertTrue(model.browser.keyboardEngaged, "鼠标点一下不该退回灰色")
    }

    func testReopeningThePanelNeverLandsYouBackInTheLastSearch() async {
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [entry("MyQuickFinder", in: studio)],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection)
        await settle(model)

        model.perform(.openPicker)
        model.picker.updateText("~/code-studio")
        await settlePicker(model)
        model.perform(.showHelp)
        model.perform(.openAncestors)
        model.perform(.openInFinder)

        model.markPresented()

        XCTAssertFalse(model.isPicking, "上一次的路径栏不该跟着面板一起回来")
        XCTAssertTrue(model.picker.text.isEmpty, "上一次打的路径也不该留着")
        XCTAssertFalse(model.showsHelp)
        XCTAssertFalse(model.showsAncestors)
        XCTAssertEqual(model.browser.directory, studio, "浏览区位置是唯一该保留的东西")
    }

    func testTypingEngagesTheKeyboardEvenWhenEveryKeystrokeGoesToThePathBar() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)
        XCTAssertFalse(model.browser.keyboardEngaged)

        model.perform(.openPicker, fromKeyboard: true)
        await settlePicker(model)
        model.perform(.moveSelection(1), fromKeyboard: true)
        model.perform(.exitPicker, fromKeyboard: true)

        XCTAssertTrue(
            model.browser.keyboardEngaged,
            "全程用键盘走的路径栏，退出后浏览区不该还画成没碰过键盘的灰色"
        )
    }

    func testClickingAnActionPillIsNotAKeyboardEngagement() async {
        let model = make(entries: [home: [entry("notes", in: home)]])
        model.browser.start()
        await settle(model)

        model.perform(.openInFinder)

        XCTAssertFalse(model.browser.keyboardEngaged, "鼠标点药丸不算碰键盘")
    }

    func testRightArrowOnAFavoriteMovesIntoTheListInsteadOfDivingAnotherLevel() async {
        let studio = home.appending(path: "code-studio")
        let atlas = studio.appending(path: "Atlas")
        let build = atlas.appending(path: "build_device")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [entry("Atlas", in: studio)],
            atlas: [entry("build_device", in: atlas), entry("docs", in: atlas)],
            build: [entry("Build", in: build)],
            atlas.appending(path: "docs"): [],
            build.appending(path: "Build"): [],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection, fromKeyboard: true)
        await settle(model)
        model.toggleFavoriteForSelection()
        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)

        XCTAssertEqual(model.zone, .favorites)
        XCTAssertEqual(model.browser.directory, atlas, "选中收藏项后浏览区已经在它里面了")

        model.perform(.enterSelection, fromKeyboard: true)
        await settle(model)

        XCTAssertEqual(model.zone, .list, "→ 是把焦点移进列表")
        XCTAssertEqual(model.browser.directory, atlas, "不该再往下钻一层")
        XCTAssertEqual(model.actionTarget, build, "高亮落在列表第一行")

        model.perform(.enterSelection, fromKeyboard: true)
        await settle(model)
        XCTAssertEqual(model.browser.directory, build, "再按一次 → 才真的进去")
    }

    func testRemovingTheLastFavoriteSendsTheBrowseAreaBackToTheRoot() async {
        let gallery = home.appending(path: "Gallery")
        let build = gallery.appending(path: "build")
        let model = make(entries: [
            home: [entry("Gallery", in: home)],
            gallery: [entry("build", in: gallery), entry("docs", in: gallery)],
            build: [],
            gallery.appending(path: "docs"): [],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection, fromKeyboard: true)
        await settle(model)
        model.toggleFavoriteForSelection()
        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)
        XCTAssertTrue(model.favoritesSelectionIsActive)

        model.perform(.toggleFavorite, fromKeyboard: true)

        XCTAssertTrue(model.favorites.isEmpty)
        XCTAssertFalse(
            model.favoritesSelectionIsActive,
            "收藏项没了，收藏区就不该还算作活跃区"
        )
        XCTAssertTrue(model.listSelectionIsActive, "焦点该落回列表")
        XCTAssertEqual(model.zone, .list)
        await settle(model)
        XCTAssertEqual(
            model.browser.directory,
            home,
            "一个收藏项都不剩了，浏览区回到根，而不是留在刚被取消收藏的那个目录里"
        )
        XCTAssertNotEqual(model.actionTarget, build)
    }

    func testRemovingAFavoriteLandsOnThePreviousOne() async {
        let names = ["Atlas", "Cobalt", "Gallery"]
        var listings: [URL: [DirectoryEntry]] = [home: names.map { entry($0, in: home) }]
        for name in names {
            listings[home.appending(path: name)] = []
        }
        let model = make(entries: listings)
        model.browser.start()
        await settle(model)
        for _ in names.indices {
            model.toggleFavoriteForSelection()
            model.browser.moveSelection(by: 1)
        }
        XCTAssertEqual(model.favorites.items.count, 3)

        model.selectFavorite(model.favorites.items[2].id)
        await settle(model)
        model.perform(.toggleFavorite, fromKeyboard: true)
        await settle(model)

        XCTAssertEqual(
            model.favorites.selected?.displayName,
            "Cobalt",
            "删掉第 3 条之后落到它上一条"
        )
        XCTAssertTrue(model.favoritesSelectionIsActive, "焦点留在收藏区")
        XCTAssertEqual(model.browser.directory, home.appending(path: "Cobalt"))

        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)
        model.perform(.toggleFavorite, fromKeyboard: true)
        await settle(model)

        XCTAssertEqual(
            model.favorites.selected?.displayName,
            "Cobalt",
            "删掉第 1 条时没有上一条，就落到新的第一条"
        )
    }

    func testTheActionBarStopsPromisingReturnWhileAnOverlayOwnsIt() async {
        let studio = home.appending(path: "code-studio")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [entry("Atlas", in: studio)],
            studio.appending(path: "Atlas"): [],
        ])
        model.browser.start()
        await settle(model)
        model.perform(.enterSelection, fromKeyboard: true)
        await settle(model)
        XCTAssertFalse(model.isOverlayOwningKeyboard, "平时动作条说了算")

        model.perform(.openAncestors, fromKeyboard: true)
        XCTAssertTrue(model.showsAncestors)
        XCTAssertTrue(
            model.isOverlayOwningKeyboard,
            "祖先菜单开着时 ↩ 是确认那一层，动作条不该还挂着「在 Finder 打开 ↩」"
        )

        model.perform(.closeAncestors, fromKeyboard: true)
        XCTAssertFalse(model.isOverlayOwningKeyboard)

        model.perform(.showHelp, fromKeyboard: true)
        XCTAssertTrue(model.isOverlayOwningKeyboard, "帮助层同理")
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
