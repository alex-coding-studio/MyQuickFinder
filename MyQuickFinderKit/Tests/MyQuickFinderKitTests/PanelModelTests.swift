import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class PanelModelTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testStarringTheSelectionAddsItAndStarringAgainRemovesIt() async {
        let storage = InMemoryFavoriteStorage()
        let model = make(entries: [home: [entry("Gallery", in: home)]], storage: storage)
        model.browser.start()
        await settle(model)

        XCTAssertTrue(model.toggleFavoriteForSelection())
        XCTAssertTrue(model.isSelectionFavorited)
        XCTAssertEqual(storage.load().items.map(\.displayName), ["Gallery"])

        XCTAssertTrue(model.toggleFavoriteForSelection())
        XCTAssertFalse(model.isSelectionFavorited)
        XCTAssertTrue(storage.load().isEmpty)
    }

    func testFilesCanBeStarredJustLikeDirectories() async {
        let model = make(entries: [home: [entry("notes.md", in: home, isDirectory: false)]])
        model.browser.start()
        await settle(model)

        XCTAssertTrue(model.canFavoriteSelection, "收藏栏不只放目录，单个文件一样能 pin")
        XCTAssertTrue(model.toggleFavoriteForSelection())
        XCTAssertEqual(model.favorites.items.first?.kind, .file, "存的时候要记住它是文件")
        XCTAssertEqual(model.favorites.items.first?.url.lastPathComponent, "notes.md")

        XCTAssertTrue(model.toggleFavoriteForSelection())
        XCTAssertTrue(model.favorites.isEmpty)
    }

    func testFavoritesSurviveARestart() async {
        let storage = InMemoryFavoriteStorage()
        let first = make(entries: [home: [entry("Gallery", in: home)]], storage: storage)
        first.browser.start()
        await settle(first)
        first.toggleFavoriteForSelection()

        let second = make(entries: [home: []], storage: storage)

        XCTAssertEqual(second.favorites.items.map(\.displayName), ["Gallery"])
    }

    func testActivatingAFavoriteDrivesTheBrowseArea() async {
        let gallery = home.appending(path: "Gallery")
        let model = make(entries: [
            home: [entry("Gallery", in: home)],
            gallery: [entry("vendor", in: gallery)],
        ])
        model.browser.start()
        await settle(model)
        model.toggleFavoriteForSelection()

        model.activateFavorite(at: 0)
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, gallery.path)
        XCTAssertEqual(model.browser.entries.map(\.name), ["vendor"])
        XCTAssertEqual(model.zone, .favorites)
    }

    func testActivatingAnIndexBeyondTheListDoesNothing() async {
        let model = make(entries: [home: []])
        model.browser.start()
        await settle(model)

        model.activateFavorite(at: 3)

        XCTAssertNil(model.favorites.selectedID)
        XCTAssertEqual(model.browser.directory.path, home.path)
    }

    func testTheFirstOpenLandsOnTheSelectedFavorite() async {
        let gallery = home.appending(path: "Gallery")
        let storage = InMemoryFavoriteStorage()
        let model = make(
            entries: [home: [entry("Gallery", in: home)], gallery: []],
            storage: storage
        )
        model.browser.start()
        await settle(model)
        model.toggleFavoriteForSelection()
        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)

        let reopened = make(
            entries: [home: [entry("Gallery", in: home)], gallery: []],
            storage: storage
        )
        reopened.restoreEntryPoint()
        await settle(reopened)

        XCTAssertEqual(reopened.browser.directory.path, gallery.path)
    }

    func testReopeningKeepsWhereverTheBrowseAreaWasLeft() async {
        let gallery = home.appending(path: "Gallery")
        let vendor = gallery.appending(path: "vendor")
        let model = make(entries: [
            home: [entry("Gallery", in: home)],
            gallery: [entry("vendor", in: gallery)],
            vendor: [entry("bundle", in: vendor)],
        ])
        model.restoreEntryPoint()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        XCTAssertEqual(model.browser.directory.path, vendor.path)

        model.restoreEntryPoint()
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, vendor.path)
    }

    func testReopeningRereadsTheDirectorySoOutsideChangesShowUp() async {
        let reader = MutableReader(entries: [home: [entry("a", in: home)]])
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.restoreEntryPoint()
        await settle(model)
        XCTAssertEqual(model.browser.entries.map(\.name), ["a"])

        reader.entries[home] = [entry("a", in: home), entry("b", in: home)]
        model.restoreEntryPoint()
        await settle(model)

        XCTAssertEqual(model.browser.entries.map(\.name), ["a", "b"])
    }

    func testSelectingAFavoriteIsWhatMovesTheBrowseArea() async {
        let gallery = home.appending(path: "Gallery")
        let vendor = gallery.appending(path: "vendor")
        let model = make(entries: [
            home: [entry("Gallery", in: home)],
            gallery: [entry("vendor", in: gallery)],
            vendor: [],
        ])
        model.restoreEntryPoint()
        await settle(model)
        model.toggleFavoriteForSelection()
        model.browser.enterSelection()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        XCTAssertEqual(model.browser.directory.path, vendor.path)

        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, gallery.path)
    }

    func testAFirstRunWithoutFavoritesOpensAtHome() async {
        let model = make(entries: [home: []])
        model.restoreEntryPoint()
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, home.path)
        XCTAssertTrue(model.favorites.isEmpty)
    }

    func testTabDoesNothingWhileTheFavoritesBarIsEmpty() async {
        let model = make(entries: [home: []])
        model.browser.start()
        await settle(model)

        model.switchZone()

        XCTAssertEqual(model.zone, .list)
    }

    func testTabMovesBetweenTheFavoritesBarAndTheList() async {
        let gallery = home.appending(path: "Gallery")
        let model = make(entries: [home: [entry("Gallery", in: home)], gallery: []])
        model.browser.start()
        await settle(model)
        model.toggleFavoriteForSelection()

        model.switchZone()
        await settle(model)
        XCTAssertEqual(model.zone, .favorites)
        XCTAssertEqual(model.favorites.selected?.displayName, "Gallery")

        model.switchZone()
        XCTAssertEqual(model.zone, .list)
    }

    func testRemovingAFavoriteIsPersisted() async {
        let storage = InMemoryFavoriteStorage()
        let model = make(entries: [home: [entry("Gallery", in: home)]], storage: storage)
        model.browser.start()
        await settle(model)
        model.toggleFavoriteForSelection()
        let id = model.favorites.items[0].id

        model.removeFavorite(id)

        XCTAssertTrue(model.favorites.isEmpty)
        XCTAssertTrue(storage.load().isEmpty)
    }

    func testReturningFromAuthorizationLandsBackOnTheBlockedDirectory() async {
        let documents = home.appending(path: "Documents")
        let reader = MutableReader(entries: [home: [entry("Documents", in: home)]])
        reader.failures[documents] = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError
        )
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        XCTAssertTrue(model.browser.isDenied)

        model.markAuthorizationRequested()
        reader.failures[documents] = nil
        reader.entries[documents] = [entry("notes", in: documents)]
        model.restoreEntryPoint()
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, documents.path)
        XCTAssertEqual(model.browser.entries.map(\.name), ["notes"])
        XCTAssertFalse(model.needsRelaunchToApplyAuthorization)
    }

    func testAStillBlockedDirectoryAfterAuthorizationAsksForARelaunch() async {
        let documents = home.appending(path: "Documents")
        let reader = MutableReader(entries: [home: [entry("Documents", in: home)]])
        reader.failures[documents] = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError
        )
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)

        model.markAuthorizationRequested()
        model.restoreEntryPoint()
        await settle(model)

        XCTAssertTrue(model.browser.isDenied)
        XCTAssertTrue(model.needsRelaunchToApplyAuthorization)
    }

    func testTheRelaunchHintGoesAwayOnceTheUserNavigatesElsewhere() async {
        let documents = home.appending(path: "Documents")
        let reader = MutableReader(entries: [home: [entry("Documents", in: home)]])
        reader.failures[documents] = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError
        )
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        model.markAuthorizationRequested()
        model.restoreEntryPoint()
        await settle(model)
        XCTAssertTrue(model.needsRelaunchToApplyAuthorization)

        model.browser.goUp()
        await settle(model)

        XCTAssertFalse(model.needsRelaunchToApplyAuthorization)
    }

    func testAnOrdinaryReopenStillLandsOnTheEntryPoint() async {
        let gallery = home.appending(path: "Gallery")
        let reader = MutableReader(entries: [home: [entry("Gallery", in: home)], gallery: []])
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        XCTAssertEqual(model.browser.directory.path, gallery.path)

        model.restoreEntryPoint()
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, home.path)
    }

    func testReloadKeepsTheDirectoryAndSelectionInPlace() async {
        let reader = MutableReader(entries: [home: [
            entry("a", in: home),
            entry("b", in: home),
            entry("c", in: home),
        ]])
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        model.browser.moveSelection(by: 2)
        XCTAssertEqual(model.browser.selectedEntry?.name, "c")

        model.refreshAfterReturningToApp()
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, home.path)
        XCTAssertEqual(model.browser.selectedEntry?.name, "c")
    }

    func testReloadClampsTheSelectionWhenTheDirectoryShrank() async {
        let reader = MutableReader(entries: [home: [
            entry("a", in: home),
            entry("b", in: home),
            entry("c", in: home),
        ]])
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: idlePicker(reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        model.browser.moveSelection(by: 2)

        reader.entries[home] = [entry("a", in: home)]
        model.refreshAfterReturningToApp()
        await settle(model)

        XCTAssertEqual(model.browser.selectionIndex, 0)
        XCTAssertEqual(model.browser.selectedEntry?.name, "a")
    }

    func testEveryPresentationIsDistinctSoFocusCanBeReestablished() {
        let model = make(entries: [home: []])
        let first = model.presentationCount

        model.markPresented()
        model.markPresented()

        XCTAssertEqual(model.presentationCount, first + 2)
    }

    func testAncestorMenuOpensOnTheClosestAncestorAndWalksToTheShallowest() async {
        let deep = home.appending(path: "a/b/c")
        let model = make(entries: [home: [], deep: []])
        model.browser.navigate(to: deep)
        await settle(model)

        model.openAncestors()

        XCTAssertTrue(model.showsAncestors)
        XCTAssertEqual(model.ancestors.map(\.name), ["~", "a", "b"])
        XCTAssertEqual(model.ancestorIndex, 2)

        model.moveAncestorSelection(by: -5)
        XCTAssertEqual(model.ancestorIndex, 0)
        model.moveAncestorSelection(by: 99)
        XCTAssertEqual(model.ancestorIndex, 2)
    }

    func testConfirmingAnAncestorNavigatesAndClosesTheMenu() async {
        let deep = home.appending(path: "a/b/c")
        let target = home.appending(path: "a")
        let model = make(entries: [home: [], deep: [], target: []])
        model.browser.navigate(to: deep)
        await settle(model)
        model.openAncestors()

        model.selectAncestor(1)
        model.confirmAncestor()
        await settle(model)

        XCTAssertFalse(model.showsAncestors)
        XCTAssertEqual(model.browser.directory.path, target.path)
    }

    func testTheAncestorMenuStaysShutAtTheVolumeRoot() async {
        let model = make(entries: [home: []])
        model.browser.navigate(to: URL(fileURLWithPath: "/"))
        await settle(model)

        model.openAncestors()

        XCTAssertFalse(model.showsAncestors)
    }

    func testOpeningHelpClosesTheAncestorMenu() async {
        let deep = home.appending(path: "a/b/c")
        let model = make(entries: [home: [], deep: []])
        model.browser.navigate(to: deep)
        await settle(model)
        model.openAncestors()

        model.setHelpVisible(true)

        XCTAssertFalse(model.showsAncestors)
        XCTAssertTrue(model.showsHelp)
    }

    func testStarringAFileRecordsItAsAFileNotADirectory() async {
        let notes = home.appending(path: "notes.md")
        let model = make(entries: [home: []])
        model.restoreEntryPoint()
        await settle(model)

        model.addFavorite(DirectoryEntry(url: notes, name: "notes.md", isDirectory: false))

        XCTAssertEqual(model.favorites.items.first?.kind, .file)
    }

    func testStarringADirectoryStillRecordsItAsADirectory() async {
        let gallery = home.appending(path: "Gallery")
        let model = make(entries: [home: []])
        model.restoreEntryPoint()
        await settle(model)

        model.addFavorite(DirectoryEntry(url: gallery, name: "Gallery", isDirectory: true))

        XCTAssertEqual(model.favorites.items.first?.kind, .directory)
    }

    func testSelectingAFileFavoriteLandsInItsFolderWithItSelected() async {
        let studio = home.appending(path: "code-studio")
        let notes = studio.appending(path: "notes.md")
        let model = make(entries: [
            home: [entry("code-studio", in: home)],
            studio: [
                entry("Gallery", in: studio),
                entry("notes.md", in: studio, isDirectory: false),
            ],
        ])
        model.restoreEntryPoint()
        await settle(model)
        model.addFavorite(DirectoryEntry(url: notes, name: "notes.md", isDirectory: false))

        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)

        XCTAssertEqual(model.browser.directory.path, studio.path)
        XCTAssertEqual(model.browser.selectedEntry?.name, "notes.md")
    }

    func testAFavoriteWhosePathIsGoneIsMarkedButKept() async {
        let alive = home.appending(path: "Gallery")
        let gone = home.appending(path: "deleted-repo")
        let storage = InMemoryFavoriteStorage(
            FavoriteList(items: [Favorite(url: alive), Favorite(url: gone)])
        )
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: StubReader(entries: [home: []])),
            picker: idlePicker(reader: StubReader(entries: [home: []])),
            storage: storage,
            existenceProbe: { $0.path != gone.path }
        )

        model.markPresented()
        for _ in 0 ..< 200 where model.missingFavoritePaths.isEmpty {
            await Task.yield()
        }

        XCTAssertTrue(model.isMissing(model.favorites.items[1]))
        XCTAssertFalse(model.isMissing(model.favorites.items[0]))
        XCTAssertEqual(model.favorites.items.count, 2)
        XCTAssertEqual(storage.load().items.count, 2)
    }

    func testAPathThatComesBackStopsBeingMarked() async {
        let gone = home.appending(path: "unmounted")
        let storage = InMemoryFavoriteStorage(FavoriteList(items: [Favorite(url: gone)]))
        let present = Locked(false)
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: StubReader(entries: [home: []])),
            picker: idlePicker(reader: StubReader(entries: [home: []])),
            storage: storage,
            existenceProbe: { _ in present.value }
        )

        model.markPresented()
        for _ in 0 ..< 200 where model.missingFavoritePaths.isEmpty {
            await Task.yield()
        }
        XCTAssertTrue(model.isMissing(model.favorites.items[0]))

        present.set(true)
        model.markPresented()
        for _ in 0 ..< 200 where model.missingFavoritePaths.isEmpty == false {
            await Task.yield()
        }

        XCTAssertFalse(model.isMissing(model.favorites.items[0]))
    }

    func testCommandDOnTheFavoritesBarRemovesThatFavoriteAndFallsBackToTheRoot() async {
        let gallery = home.appending(path: "Gallery")
        let model = make(entries: [home: [entry("Gallery", in: home)], gallery: []])
        model.restoreEntryPoint()
        await settle(model)
        model.toggleFavoriteForSelection()
        model.selectFavorite(model.favorites.items[0].id)
        await settle(model)
        XCTAssertEqual(model.zone, .favorites)

        model.toggleFavoriteForCurrentZone()
        await settle(model)

        XCTAssertTrue(model.favorites.isEmpty)
        XCTAssertEqual(model.browser.directory, home, "一条收藏都不剩了，浏览区回到根")
        XCTAssertEqual(
            model.zone,
            .list,
            "收藏区已经没有可选中的东西，焦点必须落回列表——停在一个空掉的区里就会两边都不亮"
        )
    }

    func testCommandDInTheListStillTogglesTheBrowsedSelection() async {
        let model = make(entries: [home: [entry("Gallery", in: home)]])
        model.restoreEntryPoint()
        await settle(model)
        XCTAssertEqual(model.zone, .list)

        model.toggleFavoriteForCurrentZone()

        XCTAssertEqual(model.favorites.items.map(\.displayName), ["Gallery"])
        XCTAssertEqual(model.zone, .list)
    }

    func testOnlyTheFirstTenFavoritesReportAShortcut() {
        let storage = InMemoryFavoriteStorage(
            FavoriteList(items: (1 ... 12).map { Favorite(url: home.appending(path: "dir\($0)")) })
        )
        let model = make(entries: [home: []], storage: storage)

        XCTAssertEqual(model.favoriteShortcutCapacity, FavoriteList.shortcutCapacity)
        XCTAssertEqual(model.favorites.shortcut(for: model.favorites.items[9].id), "⌘ 0")
        XCTAssertNil(model.favorites.shortcut(for: model.favorites.items[10].id))
    }

    private func entry(_ name: String, in parent: URL, isDirectory: Bool = true) -> DirectoryEntry {
        DirectoryEntry(url: parent.appending(path: name), name: name, isDirectory: isDirectory)
    }

    private func idlePicker(reader: any DirectoryReading) -> PathPickerModel {
        PathPickerModel(home: home, reader: reader)
    }

    private func settle(_ model: PanelModel) async {
        for _ in 0 ..< 200 {
            if case .loading = model.browser.state {
                await Task.yield()
                continue
            }
            break
        }
        for _ in 0 ..< 40 {
            guard let pending = model.browser.pendingLoad else {
                return
            }
            await pending.value
            await Task.yield()
            if pending.isCancelled == false {
                return
            }
        }
    }

    private func make(
        entries: [URL: [DirectoryEntry]],
        storage: any FavoriteStoring = InMemoryFavoriteStorage()
    ) -> PanelModel {
        let reader = StubReader(entries: entries)
        let browser = BrowserModel(home: home, reader: reader)
        return PanelModel(
            browser: browser,
            picker: idlePicker(reader: reader),
            storage: storage
        )
    }
}

private struct StubReader: DirectoryReading {
    private let listings: [String: [DirectoryEntry]]

    init(entries: [URL: [DirectoryEntry]]) {
        listings = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.key.standardizedFileURL.path, $0.value) }
        )
    }

    func read(
        _ url: URL,
        home _: URL,
        onProgress _: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        listings[url.standardizedFileURL.path] ?? []
    }
}

private final class MutableReader: DirectoryReading, @unchecked Sendable {
    var entries: [URL: [DirectoryEntry]]
    var failures = [URL: Error]()

    init(entries: [URL: [DirectoryEntry]]) {
        self.entries = entries
    }

    func read(
        _ url: URL,
        home _: URL,
        onProgress _: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        let key = url.standardizedFileURL.path
        if let failure = failures.first(where: { $0.key.standardizedFileURL.path == key })?.value {
            throw failure
        }
        return entries.first(where: { $0.key.standardizedFileURL.path == key })?.value ?? []
    }
}

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    var value: Value {
        lock.withLock { stored }
    }

    init(_ value: Value) {
        stored = value
    }

    func set(_ newValue: Value) {
        lock.withLock { stored = newValue }
    }
}
