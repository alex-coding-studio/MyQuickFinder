import Foundation
import XCTest
@testable import MyQuickFinderKit

final class FavoriteTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testAliasWinsOverTheLastPathComponent() {
        XCTAssertEqual(favorite("/tmp/qf-home/code-studio/Gallery").displayName, "Gallery")
        XCTAssertEqual(
            favorite("/tmp/qf-home/bin/daily-report.sh", kind: .script, alias: "日报生成").displayName,
            "日报生成"
        )
        XCTAssertEqual(favorite("/tmp/qf-home/Gallery", alias: "").displayName, "Gallery")
    }

    func testAddingTheSamePathTwiceIsRejected() {
        var favorites = list(["/tmp/qf-home/Gallery"])
        XCTAssertFalse(favorites.add(favorite("/tmp/qf-home/Gallery")))
        XCTAssertTrue(favorites.add(favorite("/tmp/qf-home/Journal")))
        XCTAssertEqual(favorites.items.count, 2)
    }

    func testDuplicateDetectionStandardizesPaths() {
        let favorites = list(["/tmp/qf-home/Gallery"])
        XCTAssertTrue(favorites.contains(url: URL(fileURLWithPath: "/tmp/qf-home/./Gallery/")))
    }

    func testRemovingTheSelectedItemClearsTheSelection() {
        var favorites = list(["/tmp/qf-home/Gallery", "/tmp/qf-home/Journal"])
        favorites.select(favorites.items[0].id)
        XCTAssertNotNil(favorites.selected)
        favorites.remove(url: URL(fileURLWithPath: "/tmp/qf-home/Gallery"))
        XCTAssertNil(favorites.selectedID)
    }

    func testRemovingAnotherItemLeavesTheSelectionAlone() {
        var favorites = list(["/tmp/qf-home/Gallery", "/tmp/qf-home/Journal"])
        let keptID = favorites.items[1].id
        favorites.select(keptID)
        favorites.remove(url: URL(fileURLWithPath: "/tmp/qf-home/Gallery"))
        XCTAssertEqual(favorites.selectedID, keptID)
    }

    func testSelectingAnUnknownIdentifierClearsRatherThanCorruptsTheSelection() {
        var favorites = list(["/tmp/qf-home/Gallery"])
        favorites.select(UUID())
        XCTAssertNil(favorites.selectedID)
    }

    func testRestoredSelectionIsDroppedWhenItsItemIsGone() {
        let orphaned = FavoriteList(items: [favorite("/tmp/qf-home/Gallery")], selectedID: UUID())
        XCTAssertNil(orphaned.selectedID)
    }

    func testReorderingMovesTheItemAndItsShortcut() {
        var favorites = list(["/tmp/qf-home/a", "/tmp/qf-home/b", "/tmp/qf-home/c"])
        let moved = favorites.items[2].id
        favorites.move(from: 2, to: 0)
        XCTAssertEqual(favorites.items.map(\.displayName), ["c", "a", "b"])
        XCTAssertEqual(favorites.shortcut(for: moved), "⌘ 1")
    }

    func testOnlyTheFirstTenItemsGetAShortcutAndTheTenthIsCommandZero() {
        let favorites = list((1 ... 12).map { "/tmp/qf-home/dir\($0)" })
        XCTAssertEqual(favorites.shortcut(for: favorites.items[0].id), "⌘ 1")
        XCTAssertEqual(favorites.shortcut(for: favorites.items[8].id), "⌘ 9")
        XCTAssertEqual(favorites.shortcut(for: favorites.items[9].id), "⌘ 0")
        XCTAssertNil(favorites.shortcut(for: favorites.items[10].id))
        XCTAssertNil(favorites.shortcut(for: favorites.items[11].id))
    }

    func testStoredFavoritesSurviveAnEncodeDecodeRoundTrip() throws {
        var favorites = FavoriteList(items: [
            favorite("/tmp/qf-home/code-studio/Gallery", alias: "相册"),
            favorite("/tmp/qf-home/bin/daily-report.sh", kind: .script, alias: "日报生成"),
            favorite("/tmp/qf-home/.zshrc", kind: .file),
        ])
        favorites.select(favorites.items[1].id)

        let restored = try FavoriteStore.decode(FavoriteStore.encode(favorites))

        XCTAssertEqual(restored, favorites)
        XCTAssertEqual(restored.items.map(\.kind), [.directory, .script, .file])
        XCTAssertEqual(restored.items.map(\.alias), ["相册", "日报生成", nil])
        XCTAssertEqual(restored.selected?.displayName, "日报生成")
    }

    func testStoredPayloadCarriesASchemaVersion() throws {
        let data = try FavoriteStore.encode(list(["/tmp/qf-home/Gallery"]))
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(raw["version"] as? Int, FavoriteStore.currentVersion)
    }

    func testPanelOpensOnTheSelectedFavoriteRatherThanHome() {
        var favorites = list(["/tmp/qf-home/code-studio/Gallery"])
        favorites.select(favorites.items[0].id)
        XCTAssertEqual(
            PanelEntry.startingDirectory(favorites: favorites, home: home).path,
            "/tmp/qf-home/code-studio/Gallery"
        )
    }

    func testPanelFallsBackToHomeWithoutASelection() {
        XCTAssertEqual(
            PanelEntry.startingDirectory(favorites: list(["/tmp/qf-home/Gallery"]), home: home),
            home
        )
        XCTAssertEqual(PanelEntry.startingDirectory(favorites: FavoriteList(), home: home), home)
    }

    func testPanelOpensAtTheFolderHoldingANonDirectoryFavorite() {
        var favorites = FavoriteList(items: [favorite(
            "/tmp/qf-home/bin/daily-report.sh",
            kind: .script
        )])
        favorites.select(favorites.items[0].id)

        XCTAssertEqual(
            PanelEntry.startingDirectory(favorites: favorites, home: home).standardizedFileURL.path,
            "/tmp/qf-home/bin",
            "文件与脚本类收藏项冷启动落在它所在的目录，不再甩回 ~"
        )
    }

    func testPanelStillFallsBackToHomeWithNoSelectedFavorite() {
        let favorites = FavoriteList(items: [favorite("/tmp/qf-home/bin", kind: .directory)])
        XCTAssertEqual(PanelEntry.startingDirectory(favorites: favorites, home: home), home)
    }

    private func favorite(
        _ path: String,
        kind: Favorite.Kind = .directory,
        alias: String? = nil
    ) -> Favorite {
        Favorite(url: URL(fileURLWithPath: path), kind: kind, alias: alias)
    }

    private func list(_ paths: [String]) -> FavoriteList {
        FavoriteList(items: paths.map { favorite($0) })
    }
}
