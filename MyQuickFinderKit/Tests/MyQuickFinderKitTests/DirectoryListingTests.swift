import Foundation
import XCTest
@testable import MyQuickFinderKit

final class DirectoryListingTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testDirectoriesSortAboveFilesAndIgnoreCaseWithinEachGroup() {
        let arranged = DirectoryListing.arrange(
            [
                entry("project.yml", isDirectory: false),
                entry("vendor"),
                entry("README.md", isDirectory: false),
                entry("fastlane"),
                entry("Gallery"),
            ],
            showingHidden: false
        )
        XCTAssertEqual(
            arranged.entries.map(\.name),
            ["fastlane", "Gallery", "vendor", "project.yml", "README.md"]
        )
    }

    func testHiddenEntriesAreCountedRatherThanListed() {
        let arranged = DirectoryListing.arrange(
            [entry("Public"), entry(".zshrc", isDirectory: false), entry(".config")],
            showingHidden: false
        )
        XCTAssertEqual(arranged.entries.map(\.name), ["Public"])
        XCTAssertEqual(arranged.hiddenCount, 2)
    }

    func testRevealingHiddenEntriesListsThemAndClearsTheCount() {
        let arranged = DirectoryListing.arrange(
            [entry("Public"), entry(".config")],
            showingHidden: true
        )
        XCTAssertEqual(arranged.entries.map(\.name), [".config", "Public"])
        XCTAssertEqual(arranged.hiddenCount, 0)
    }

    func testTimeColumnFollowsTheVisibleNames() {
        let hashName = "c7116f70f2c208ce4f1d796e2e7ee472daa9dffdcc1de0302c4ccc35aa6cf97f"
        XCTAssertTrue(DirectoryListing.arrange(
            [entry("raw"), entry(hashName)],
            showingHidden: false
        ).showsTimeColumn)
        XCTAssertFalse(DirectoryListing.arrange(
            [entry("raw"), entry("Public")],
            showingHidden: false
        ).showsTimeColumn)
    }

    func testAnEmptyDirectoryReportsEmpty() {
        let arranged = DirectoryListing.arrange([], showingHidden: false)
        XCTAssertEqual(DirectoryListing.state(for: arranged), .empty)
    }

    func testADirectoryHoldingOnlyHiddenEntriesIsNotEmptyOnceRevealed() {
        let hiddenOnly = [entry(".config")]
        XCTAssertEqual(
            DirectoryListing.state(for: DirectoryListing.arrange(hiddenOnly, showingHidden: false)),
            .empty
        )
        XCTAssertNotEqual(
            DirectoryListing.state(for: DirectoryListing.arrange(hiddenOnly, showingHidden: true)),
            .empty
        )
    }

    func testCocoaPermissionFailureIsDeniedRatherThanEmpty() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        XCTAssertEqual(DirectoryListing.state(for: error), .denied)
    }

    func testPosixPermissionFailuresAreDenied() {
        XCTAssertEqual(
            DirectoryListing.state(for: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))),
            .denied
        )
        XCTAssertEqual(
            DirectoryListing.state(for: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))),
            .denied
        )
    }

    func testPermissionFailureWrappedInAnotherErrorIsStillDenied() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        let wrapper = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadUnknownError,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )
        XCTAssertEqual(DirectoryListing.state(for: wrapper), .denied)
    }

    func testADeletedDirectoryReadsAsMissingRatherThanARawFailure() {
        XCTAssertEqual(
            DirectoryListing.state(for: NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadNoSuchFileError
            )),
            .missing
        )
        XCTAssertEqual(
            DirectoryListing.state(for: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))),
            .missing
        )
    }

    func testAnUnrelatedFailureIsNeitherDeniedNorEmpty() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
        guard case .failed = DirectoryListing.state(for: error) else {
            return XCTFail("Unrelated failures must stay distinguishable from denied and empty")
        }
    }

    func testTheThreeTCCDirectoriesInHomeAreKnownProtectedBeforeEntering() {
        for name in ProtectedDirectory.homeChildren {
            XCTAssertTrue(
                ProtectedDirectory.isProtected(home.appending(path: name), home: home),
                name
            )
        }
    }

    func testReadabilityIsProbedAgainstTheRealDirectory() throws {
        let manager = FileManager.default
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appending(
            path: "probe-\(UUID().uuidString)"
        )
        try manager.createDirectory(at: scratch, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scratch.path
            )
            try? FileManager.default.removeItem(at: scratch)
        }

        XCTAssertTrue(ProtectedDirectory.isReadable(scratch))
        try manager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: scratch.path)
        XCTAssertFalse(ProtectedDirectory.isReadable(scratch))
    }

    func testAMissingDirectoryIsNotReadable() {
        XCTAssertFalse(
            ProtectedDirectory.isReadable(home.appending(path: "absent-\(UUID().uuidString)"))
        )
    }

    func testOrdinaryHomeChildrenAndDeeperNamesakesAreNotMarkedProtected() {
        XCTAssertFalse(ProtectedDirectory.isProtected(home.appending(path: "Public"), home: home))
        XCTAssertFalse(ProtectedDirectory.isProtected(
            home.appending(path: "code-studio/Documents"),
            home: home
        ))
        XCTAssertFalse(ProtectedDirectory.isProtected(
            URL(fileURLWithPath: "/tmp/qf-homestead/Documents"),
            home: home
        ))
    }

    private func entry(_ name: String, isDirectory: Bool = true) -> DirectoryEntry {
        DirectoryEntry(
            url: URL(fileURLWithPath: "/tmp/qf-home/code-studio/Gallery").appending(
                path: name
            ),
            name: name,
            isDirectory: isDirectory
        )
    }
}
