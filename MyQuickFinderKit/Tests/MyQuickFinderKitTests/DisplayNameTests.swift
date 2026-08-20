import Foundation
import XCTest
@testable import MyQuickFinderKit

final class DisplayNameTests: XCTestCase {
    private let hashName = "c7116f70f2c208ce4f1d796e2e7ee472daa9dffdcc1de0302c4ccc35aa6cf97f"
    private let longReadableName = "PrototypePlayground-7c6ad36cdc0fbaa55a27f41d6f7e6f4f-VFS-iphonesimulator"

    func testShortNameIsShownWhole() {
        let rendered = DisplayName.render("Public")
        XCTAssertEqual(rendered.text, "Public")
        XCTAssertEqual(rendered.treatment, .plain)
    }

    func testNameAtTheLimitIsStillShownWhole() {
        let raw = String(repeating: "a", count: DisplayName.plainLimit)
        XCTAssertEqual(DisplayName.render(raw).treatment, .plain)
    }

    func testReadableLongNameKeepsItsSemanticSuffix() {
        XCTAssertEqual(longReadableName.count, 72)
        let rendered = DisplayName.render(longReadableName)
        XCTAssertEqual(rendered.treatment, .middleTruncated)
        XCTAssertEqual(rendered.text, "Prototype…phonesimulator")
        XCTAssertEqual(rendered.text.count, DisplayName.plainLimit)
        XCTAssertTrue(
            rendered.text.hasSuffix(String(longReadableName.suffix(DisplayName.trailingKeep)))
        )
    }

    func testHashNameIsCutToItsLeadingDigits() {
        XCTAssertEqual(hashName.count, 64)
        let rendered = DisplayName.render(hashName)
        XCTAssertEqual(rendered.treatment, .hash)
        XCTAssertEqual(rendered.text, "c7116f70f2…")
    }

    func testHashDetectionRejectsUppercaseAndShortDigests() {
        XCTAssertFalse(DisplayName.isHash(hashName.uppercased()))
        XCTAssertFalse(DisplayName.isHash(String(
            repeating: "a",
            count: DisplayName.hashMinimumLength - 1
        )))
        XCTAssertTrue(DisplayName.isHash(String(
            repeating: "a",
            count: DisplayName.hashMinimumLength
        )))
    }

    func testHashDetectionRejectsNonHexCharacters() {
        XCTAssertFalse(DisplayName.isHash("z" + hashName.dropFirst()))
    }

    func testTimeColumnAppearsWhenTheDirectoryHoldsAHashName() {
        XCTAssertTrue(DisplayName.needsTimeColumn(names: ["raw", hashName]))
    }

    func testTimeColumnAppearsWhenTwoNamesCollideAfterTruncation() {
        let names = [
            "Prototype-aaaa-VFS-iphonesimulator-phonesimulator",
            "Prototype-bbbb-VFS-iphonesimulator-phonesimulator",
        ]
        XCTAssertEqual(DisplayName.render(names[0]).text, DisplayName.render(names[1]).text)
        XCTAssertTrue(DisplayName.needsTimeColumn(names: names))
    }

    func testTimeColumnStaysAwayFromAnOrdinaryDirectory() {
        XCTAssertFalse(DisplayName.needsTimeColumn(names: [
            "Applications",
            "Public",
            "raw",
            "trading",
        ]))
    }
}
