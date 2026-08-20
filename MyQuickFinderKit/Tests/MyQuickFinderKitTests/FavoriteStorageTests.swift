import Foundation
import XCTest
@testable import MyQuickFinderKit

final class FavoriteStorageTests: XCTestCase {
    private let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "FavoriteStorageTests-\(UUID().uuidString)")

    private var storage: FavoriteFileStorage {
        FavoriteFileStorage(url: directory.appending(path: FavoriteFileStorage.fileName))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testAFirstRunWithNoFileLoadsAnEmptyList() {
        XCTAssertTrue(storage.load().isEmpty)
    }

    func testSavingCreatesTheContainingDirectory() throws {
        let list = FavoriteList(
            items: [Favorite(url: URL(fileURLWithPath: "/tmp/qf-home/Gallery"))]
        )
        try storage.save(list)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(storage.load().items.map(\.displayName), ["Gallery"])
    }

    func testSelectionAndAliasSurviveTheRoundTrip() throws {
        var list = FavoriteList(items: [
            Favorite(url: URL(fileURLWithPath: "/tmp/qf-home/Gallery"), alias: "相册"),
            Favorite(url: URL(fileURLWithPath: "/tmp/qf-home/bin/report.sh"), kind: .script),
        ])
        list.select(list.items[1].id)
        try storage.save(list)

        let restored = storage.load()

        XCTAssertEqual(restored, list)
        XCTAssertEqual(restored.selected?.kind, .script)
        XCTAssertEqual(restored.items.first?.alias, "相册")
    }

    func testACorruptFileFallsBackToAnEmptyListRatherThanCrashing() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appending(path: FavoriteFileStorage.fileName))

        XCTAssertTrue(storage.load().isEmpty)
    }
}
