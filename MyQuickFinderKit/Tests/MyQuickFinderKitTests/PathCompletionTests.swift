import Foundation
import XCTest
@testable import MyQuickFinderKit

final class PathCompletionTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")
    private let base = URL(fileURLWithPath: "/tmp/qf-home/code-studio")

    func testEmptyInputListsWhereTheUserAlreadyIs() {
        let input = parse("")
        XCTAssertEqual(input.directory.path, base.path)
        XCTAssertEqual(input.fragment, "")
    }

    func testATildeListsHome() {
        let input = parse("~")
        XCTAssertEqual(input.directory.path, home.path)
        XCTAssertEqual(input.fragment, "")
    }

    func testATrailingSlashListsThatDirectory() {
        let input = parse("~/code-studio/")
        XCTAssertEqual(input.directory.path, "/tmp/qf-home/code-studio")
        XCTAssertEqual(input.fragment, "")
    }

    func testAPartialLastComponentBecomesTheFilter() {
        let input = parse("~/code")
        XCTAssertEqual(input.directory.path, home.path)
        XCTAssertEqual(input.fragment, "code")
    }

    func testBareTextFiltersTheCurrentDirectory() {
        let input = parse("Gal")
        XCTAssertEqual(input.directory.path, base.path)
        XCTAssertEqual(input.fragment, "Gal")
    }

    func testAbsolutePathsResolveFromTheRoot() {
        let input = parse("/usr/bi")
        XCTAssertEqual(input.directory.path, "/usr")
        XCTAssertEqual(input.fragment, "bi")
    }

    func testTheWholePathIsOfferedSoAnExistingDirectoryCanWin() {
        XCTAssertEqual(
            PathCompletion.wholePath("~/Gallery", home: home, base: base)?.path,
            "/tmp/qf-home/Gallery"
        )
        XCTAssertEqual(
            PathCompletion.wholePath("/usr/bin", home: home, base: base)?.path,
            "/usr/bin"
        )
        XCTAssertNil(PathCompletion.wholePath("", home: home, base: base))
    }

    func testPrefixMatchesComeBeforeSubstringMatches() {
        let filtered = PathCompletion.filter(
            [entry("my-gallery"), entry("Gallery"), entry("gallery-tools")],
            fragment: "gal"
        )
        XCTAssertEqual(filtered.map(\.name), ["Gallery", "gallery-tools", "my-gallery"])
    }

    func testAnEmptyFragmentKeepsTheListingUntouched() {
        let entries = [entry("b"), entry("a")]
        XCTAssertEqual(PathCompletion.filter(entries, fragment: "").map(\.name), ["b", "a"])
    }

    func testCompletingADirectoryAppendsASeparatorSoTheNextListingIsItsContents() {
        let completed = PathCompletion.complete(
            "~/Gal",
            with: entry("Gallery"),
            home: home,
            base: base
        )
        XCTAssertEqual(completed, "~/Gallery/")
    }

    func testCompletingAFileDoesNotAppendASeparator() {
        let completed = PathCompletion.complete(
            "~/not",
            with: entry("notes.md", isDirectory: false),
            home: home,
            base: base
        )
        XCTAssertEqual(completed, "~/notes.md")
    }

    func testSeveralCandidatesCompleteToTheirSharedPrefix() {
        let entries = [entry("captain-agents"), entry("captain-core"), entry("captain-docs")]
        XCTAssertEqual(PathCompletion.commonPrefix(of: entries), "captain-")
        XCTAssertEqual(
            PathCompletion.completeToCommonPrefix(
                "~/cap",
                entries: entries,
                home: home,
                base: base
            ),
            "~/captain-"
        )
    }

    func testASingleCandidateHasNoSharedPrefixToOffer() {
        XCTAssertNil(PathCompletion.commonPrefix(of: [entry("Gallery")]))
    }

    func testCandidatesWithNothingInCommonOfferNothing() {
        XCTAssertNil(PathCompletion.commonPrefix(of: [entry("alpha"), entry("beta")]))
    }

    func testTheSharedPrefixIsRefusedWhenItWouldNotGrowTheInput() {
        let entries = [entry("captain-core"), entry("captain-docs")]
        XCTAssertNil(
            PathCompletion.completeToCommonPrefix(
                "~/captain-",
                entries: entries,
                home: home,
                base: base
            )
        )
    }

    func testCompletingBareTextGrowsFromTheCurrentDirectory() {
        let completed = PathCompletion.complete(
            "Gal",
            with: entry("Gallery"),
            home: home,
            base: base
        )
        XCTAssertEqual(completed, "~/code-studio/Gallery/")
    }

    private func parse(_ raw: String) -> PathInput {
        PathCompletion.parse(raw, home: home, base: base)
    }

    private func entry(_ name: String, isDirectory: Bool = true) -> DirectoryEntry {
        DirectoryEntry(url: base.appending(path: name), name: name, isDirectory: isDirectory)
    }
}
