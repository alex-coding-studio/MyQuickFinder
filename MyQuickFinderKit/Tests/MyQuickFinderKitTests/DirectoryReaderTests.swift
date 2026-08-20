import Foundation
import XCTest
@testable import MyQuickFinderKit

final class DirectoryReaderTests: XCTestCase {
    private let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "MyQuickFinderKitTests-\(UUID().uuidString)")
    private let manager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if manager.fileExists(atPath: root.path) {
            try? manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try manager.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    func testDirectoriesAndFilesAreDistinguished() throws {
        _ = try makeDirectory("vendor")
        _ = try makeFile("README.md")

        let entries = try DirectoryReader().read(root, home: root)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(byName["vendor"]?.isDirectory, true)
        XCTAssertEqual(byName["README.md"]?.isDirectory, false)
        XCTAssertNotNil(byName["README.md"]?.modifiedAt)
    }

    func testAnEmptyDirectoryReadsAsEmptyRatherThanFailing() throws {
        let entries = try DirectoryReader().read(root, home: root)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertEqual(
            DirectoryListing.state(for: DirectoryListing.arrange(entries, showingHidden: false)),
            .empty
        )
    }

    func testProgressReportsTheRealTotalBeforeTheWorkFinishes() throws {
        for index in 0 ..< 5 {
            _ = try makeFile("file\(index)")
        }
        let reports = Locked<[(Int, Int)]>([])
        _ = try DirectoryReader(stride: 2).read(root, home: root) { read, total in
            reports.append((read, total))
        }
        let observed = reports.value
        XCTAssertEqual(observed.first?.0, 0)
        XCTAssertEqual(observed.first?.1, 5)
        XCTAssertTrue(observed.allSatisfy { $0.1 == 5 })
        XCTAssertEqual(observed.last?.0, 5)
        XCTAssertEqual(observed.map(\.0), [0, 2, 4, 5])
    }

    func testTCCGovernedChildrenAreMarkedFromTheNameWithoutTouchingThem() throws {
        _ = try makeDirectory("Documents")
        _ = try makeDirectory("Public")

        let entries = try DirectoryReader().read(root, home: root)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        XCTAssertEqual(byName["Documents"]?.isBlocked, true)
        XCTAssertEqual(byName["Public"]?.isBlocked, false)
    }

    func testAnUnreadableOrdinaryDirectoryIsNotProbedAndSoIsNotMarked() throws {
        let blocked = try makeDirectory("blocked")
        try manager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: blocked.path)
        let blockedPath = blocked.path
        addTeardownBlock {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: blockedPath
            )
        }

        let entries = try DirectoryReader().read(root, home: root)

        XCTAssertEqual(entries.first { $0.name == "blocked" }?.isBlocked, false)
    }

    func testFilesAreNeverMarkedBlocked() throws {
        _ = try makeFile("notes.md")
        let entries = try DirectoryReader().read(root, home: root)
        XCTAssertEqual(entries.first { $0.name == "notes.md" }?.isBlocked, false)
    }

    func testAnUnreadableDirectoryFailsAsDeniedRatherThanReadingEmpty() throws {
        let blocked = try makeDirectory("blocked")
        _ = try makeFile("hidden-content", in: blocked)
        try manager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: blocked.path)
        let blockedPath = blocked.path
        addTeardownBlock {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: blockedPath
            )
        }

        do {
            let entries = try DirectoryReader().read(blocked, home: root)
            XCTFail("Expected a permission failure, read \(entries.count) entries instead")
        } catch {
            XCTAssertEqual(DirectoryListing.state(for: error), .denied)
        }
    }

    func testAMissingDirectoryIsNotReportedAsDenied() throws {
        do {
            _ = try DirectoryReader().read(root.appending(path: "absent"), home: root)
            XCTFail("Expected a failure for a directory that does not exist")
        } catch {
            XCTAssertNotEqual(DirectoryListing.state(for: error), .denied)
        }
    }

    private func makeDirectory(_ name: String, in parent: URL? = nil) throws -> URL {
        let url = (parent ?? root).appending(path: name)
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeFile(_ name: String, in parent: URL? = nil) throws -> URL {
        let url = (parent ?? root).appending(path: name)
        try Data("x".utf8).write(to: url)
        return url
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

    func append<Element>(_ element: Element) where Value == [Element] {
        lock.withLock { stored.append(element) }
    }
}
