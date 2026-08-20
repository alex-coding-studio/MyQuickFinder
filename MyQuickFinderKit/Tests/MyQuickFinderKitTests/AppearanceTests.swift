import Foundation
import XCTest
@testable import MyQuickFinderKit

final class AppearanceTests: XCTestCase {
    func testDefaultsToFollowingTheSystem() {
        XCTAssertEqual(InMemoryAppearanceStorage().load(), .system)
    }

    func testAChoiceSurvivesARestart() throws {
        let storage = InMemoryAppearanceStorage()
        try storage.save(.dark)
        XCTAssertEqual(storage.load(), .dark)
    }

    func testAnUnreadableFileFallsBackToTheSystemRatherThanGuessing() {
        let missing = URL(fileURLWithPath: "/tmp/mqf-appearance-does-not-exist.json")
        XCTAssertEqual(AppearanceFileStorage(url: missing).load(), .system)
    }

    func testAFileOnDiskRoundTripsEveryChoice() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "mqf-appearance-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = AppearanceFileStorage(url: url)

        for choice in Appearance.allCases {
            try storage.save(choice)
            XCTAssertEqual(AppearanceFileStorage(url: url).load(), choice)
        }
    }

    func testGarbageOnDiskDoesNotCrashOrStick() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "mqf-appearance-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)

        XCTAssertEqual(AppearanceFileStorage(url: url).load(), .system)
    }
}
