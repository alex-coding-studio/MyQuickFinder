import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class PathPickerModelTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testTypingATildeListsHome() async {
        let reader = MapReader(entries: [home: [
            entry("code-studio", in: home),
            entry("Public", in: home),
        ]])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)

        model.updateText("~")
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), ["code-studio", "Public"])
        XCTAssertEqual(model.resolvedDirectory.path, home.path)
    }

    func testTypingAnExistingPathListsItsContentsRatherThanFilteringTheParent() async {
        let studio = home.appending(path: "code-studio")
        let reader = MapReader(entries: [
            home: [entry("code-studio", in: home)],
            studio: [entry("Gallery", in: studio), entry("Journal", in: studio)],
        ])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)

        model.updateText("~/code-studio")
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), ["Gallery", "Journal"])
        XCTAssertEqual(model.resolvedDirectory.path, studio.path)
    }

    func testAPartialNameFiltersTheParentInstead() async {
        let reader = MapReader(entries: [
            home: [entry("code-studio", in: home), entry("Public", in: home)],
        ])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)

        model.updateText("~/code")
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), ["code-studio"])
        XCTAssertEqual(model.resolvedDirectory.path, home.path)
    }

    func testBareTextFiltersWhereverTheUserWasBrowsing() async {
        let studio = home.appending(path: "code-studio")
        let reader = MapReader(entries: [studio: [
            entry("Gallery", in: studio),
            entry("Journal", in: studio),
        ]])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: studio)
        await settle(model)

        model.updateText("Gal")
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), ["Gallery"])
    }

    func testAnUnreadableDirectoryIsReportedAsDeniedRatherThanEmpty() async {
        let reader = MapReader(entries: [:])
        reader.failures[home] = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError
        )
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)

        XCTAssertEqual(model.state, .denied)
        XCTAssertNotEqual(model.state, .empty)
    }

    func testATypoIsReportedAsMissingRatherThanEmpty() async {
        let reader = MapReader(entries: [home: []])
        reader.failures[home.appending(path: "nope")] = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoSuchFileError
        )
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)

        model.updateText("~/nope/")
        await settle(model)

        XCTAssertEqual(model.state, .missing)
    }

    func testCompletingASelectedDirectoryProducesTheNextPath() async {
        let reader = MapReader(entries: [home: [entry("code-studio", in: home)]])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)
        model.updateText("~/code")
        await settle(model)

        XCTAssertEqual(model.completionText(), "~/code-studio/")
    }

    func testHiddenEntriesAppearOnlyWhenTheFragmentStartsWithADot() async {
        let reader = MapReader(entries: [home: [
            entry("Public", in: home),
            entry(".config", in: home),
        ]])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)
        XCTAssertEqual(model.entries.map(\.name), ["Public"])

        model.updateText("~/.")
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), [".config"])
    }

    func testClearingTheTextReturnsToWhereThePickerStarted() async {
        let studio = home.appending(path: "code-studio")
        let reader = MapReader(entries: [
            studio: [entry("Gallery", in: studio), entry("Journal", in: studio)],
        ])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: studio)
        await settle(model)
        model.updateText("Gal")
        await settle(model)
        XCTAssertEqual(model.entries.map(\.name), ["Gallery"])

        model.updateText("")
        await settle(model)

        XCTAssertEqual(model.text, "")
        XCTAssertEqual(model.entries.map(\.name), ["Gallery", "Journal"])
        XCTAssertEqual(model.resolvedDirectory.path, studio.path)
    }

    func testAGrantedProtectedDirectoryLosesItsLockInThePickerToo() async {
        let documents = home.appending(path: "Documents")
        let blocked = DirectoryEntry(
            url: documents,
            name: "Documents",
            isDirectory: true,
            isBlocked: true
        )
        let reader = MapReader(entries: [home: [blocked, entry("Public", in: home)]])
        let model = PathPickerModel(home: home, reader: reader, readabilityProbe: { _ in true })

        model.activate(from: home)
        await settle(model)

        XCTAssertEqual(model.entries.first { $0.name == "Documents" }?.isBlocked, false)
    }

    func testAStillBlockedDirectoryKeepsItsLockInThePicker() async {
        let documents = home.appending(path: "Documents")
        let blocked = DirectoryEntry(
            url: documents,
            name: "Documents",
            isDirectory: true,
            isBlocked: true
        )
        let reader = MapReader(entries: [home: [blocked]])
        let model = PathPickerModel(home: home, reader: reader, readabilityProbe: { _ in false })

        model.activate(from: home)
        await settle(model)

        XCTAssertEqual(model.entries.first { $0.name == "Documents" }?.isBlocked, true)
    }

    func testOpeningThePickerStartsFromWhereTheUserAlreadyIs() async {
        let studio = home.appending(path: "code-studio")
        let reader = MapReader(entries: [studio: [entry("Gallery", in: studio)]])
        let model = PathPickerModel(home: home, reader: reader)

        model.activate(from: studio)
        await settle(model)

        XCTAssertEqual(model.text, "~/code-studio/")
        XCTAssertEqual(model.resolvedDirectory.path, studio.path)
        XCTAssertEqual(model.entries.map(\.name), ["Gallery"])
    }

    func testEveryActivationBumpsTheTokenSoTheFieldCanReselect() async {
        let reader = MapReader(entries: [home: []])
        let model = PathPickerModel(home: home, reader: reader)
        let before = model.activationCount

        model.activate(from: home)
        model.deactivate()
        model.activate(from: home)
        await settle(model)

        XCTAssertEqual(model.activationCount, before + 2)
    }

    func testLeavingThePickerClearsItsState() async {
        let reader = MapReader(entries: [home: [entry("Public", in: home)]])
        let model = PathPickerModel(home: home, reader: reader)
        model.activate(from: home)
        await settle(model)

        model.deactivate()

        XCTAssertFalse(model.isActive)
        XCTAssertEqual(model.text, "")
        XCTAssertNil(model.selectedEntry)
    }

    private func entry(_ name: String, in parent: URL, isDirectory: Bool = true) -> DirectoryEntry {
        DirectoryEntry(url: parent.appending(path: name), name: name, isDirectory: isDirectory)
    }

    private func settle(_ model: PathPickerModel) async {
        for _ in 0 ..< 20 {
            guard let pending = model.pendingLoad else {
                return
            }
            await pending.value
            await Task.yield()
            if model.pendingLoad == nil || model.pendingLoad?.isCancelled == true {
                return
            }
            if pending.isCancelled == false {
                return
            }
        }
    }
}

private final class MapReader: DirectoryReading, @unchecked Sendable {
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
        if let failure = failures[url] {
            throw failure
        }
        guard let found = entries[url] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return found
    }
}
