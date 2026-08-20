import Foundation
import XCTest
@testable import MyQuickFinderKit

final class HotKeyBindingTests: XCTestCase {
    private static let optionSpace = HotKeyBinding(keyCode: 49, carbonModifiers: 2048)

    private let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "HotKeyTests-\(UUID().uuidString)")

    private var storage: HotKeyFileStorage {
        HotKeyFileStorage(
            url: directory.appending(path: HotKeyFileStorage.fileName),
            fallback: Self.optionSpace
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testAFirstRunFallsBackToOptionSpace() {
        XCTAssertEqual(storage.load(), Self.optionSpace)
    }

    func testARecordedBindingSurvivesARestart() throws {
        let recorded = HotKeyBinding(keyCode: 8, carbonModifiers: 256 | 2048)
        try storage.save(recorded)

        XCTAssertEqual(storage.load(), recorded)
    }

    func testACorruptFileFallsBackRatherThanCrashing() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appending(path: HotKeyFileStorage.fileName))

        XCTAssertEqual(storage.load(), Self.optionSpace)
    }

    func testABindingWithoutModifiersIsRecognisableAsInvalid() {
        XCTAssertFalse(HotKeyBinding(keyCode: 49, carbonModifiers: 0).hasModifier)
        XCTAssertTrue(Self.optionSpace.hasModifier)
    }
}
