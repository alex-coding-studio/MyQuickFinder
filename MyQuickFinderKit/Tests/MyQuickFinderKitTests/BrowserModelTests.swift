import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class BrowserModelTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testPopulatedDirectorySelectsItsFirstRow() async {
        let reader = FakeReader()
        reader.entries[home] = [entry("Applications", in: home), entry("Public", in: home)]
        let model = BrowserModel(home: home, reader: reader)

        model.start()
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), ["Applications", "Public"])
        XCTAssertEqual(model.selectionIndex, 0)
        XCTAssertFalse(model.keyboardEngaged)
    }

    func testDeniedDirectoryNeverPresentsAsEmpty() async {
        let reader = FakeReader()
        reader.failures[home] = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError
        )
        let model = BrowserModel(home: home, reader: reader)

        model.start()
        await settle(model)

        XCTAssertEqual(model.state, .denied)
        XCTAssertNotEqual(model.state, .empty)
        XCTAssertTrue(model.isDenied)
    }

    func testTrulyEmptyDirectoryPresentsAsEmpty() async {
        let reader = FakeReader()
        reader.entries[home] = []
        let model = BrowserModel(home: home, reader: reader)

        model.start()
        await settle(model)

        XCTAssertEqual(model.state, .empty)
        XCTAssertFalse(model.isDenied)
    }

    func testSelectionStopsAtBothEndsOfTheList() async {
        let reader = FakeReader()
        reader.entries[home] = [entry("a", in: home), entry("b", in: home)]
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)

        model.moveSelection(by: -1)
        XCTAssertEqual(model.selectionIndex, 0)
        XCTAssertTrue(model.keyboardEngaged)

        model.moveSelection(by: 5)
        XCTAssertEqual(model.selectionIndex, 1)
    }

    func testEnteringADirectoryNavigatesAndEnteringAFileDoesNot() async {
        let reader = FakeReader()
        let child = home.appending(path: "Gallery")
        reader.entries[home] = [
            entry("Gallery", in: home),
            entry("notes.md", in: home, isDirectory: false),
        ]
        reader.entries[child] = [entry("vendor", in: child)]
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)

        model.enterSelection()
        await settle(model)
        XCTAssertEqual(model.directory.path, child.path)
        XCTAssertEqual(model.entries.map(\.name), ["vendor"])

        model.navigate(to: home)
        await settle(model)
        model.selectRow(1)
        model.enterSelection()
        await settle(model)
        XCTAssertEqual(model.directory.path, home.path)
    }

    func testGoingUpFromHomeLeavesHome() async {
        let reader = FakeReader()
        reader.entries[home] = []
        reader.entries[URL(fileURLWithPath: "/tmp")] = []
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)

        model.goUp()
        await settle(model)

        XCTAssertEqual(model.directory.path, "/tmp")
        XCTAssertEqual(model.breadcrumb.root.name, "/")
    }

    func testHiddenEntriesAreCountedUntilRevealed() async {
        let reader = FakeReader()
        reader.entries[home] = [entry("Public", in: home), entry("config", in: home, hidden: true)]
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)

        XCTAssertEqual(model.entries.map(\.name), ["Public"])
        XCTAssertEqual(model.arranged.hiddenCount, 1)

        model.toggleHidden()
        XCTAssertEqual(model.entries.map(\.name), [".config", "Public"])
        XCTAssertEqual(model.arranged.hiddenCount, 0)
    }

    func testSelectionIsClampedWhenHidingEntriesShrinksTheList() async {
        let reader = FakeReader()
        reader.entries[home] = [
            entry("Public", in: home),
            entry("a", in: home, hidden: true),
            entry("b", in: home, hidden: true),
        ]
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)
        model.toggleHidden()
        model.moveSelection(by: 2)
        XCTAssertEqual(model.selectionIndex, 2)

        model.toggleHidden()

        XCTAssertEqual(model.entries.count, 1)
        XCTAssertEqual(model.selectionIndex, 0)
        XCTAssertNotNil(model.selectedEntry)
    }

    func testLoadingSurfacesTheRealCountRatherThanAnIndefiniteSpinner() async {
        let reader = FakeReader()
        let big = home.appending(path: "bin")
        reader.entries[big] = []
        reader.progressReports[big] = [(0, 924), (312, 924)]
        reader.gated.insert(big)
        let model = BrowserModel(home: home, reader: reader)

        model.navigate(to: big)
        for _ in 0 ..< 1000 {
            if case let .loading(read, total) = model.state, read == 312, total == 924 {
                break
            }
            await Task.yield()
        }

        guard case let .loading(read, total) = model.state else {
            return XCTFail(
                "Expected the panel to stay in a loading state while the read is in flight"
            )
        }
        XCTAssertEqual(total, 924)
        XCTAssertEqual(read, 312)

        reader.release()
        await settle(model)
        XCTAssertEqual(model.state, .empty)
    }

    func testAStaleDirectoryReadCannotOverwriteANewerOne() async {
        let reader = FakeReader()
        let slow = home.appending(path: "slow")
        let quick = home.appending(path: "quick")
        reader.entries[slow] = [entry("stale", in: slow)]
        reader.entries[quick] = [entry("fresh", in: quick)]
        reader.gated.insert(slow)
        let model = BrowserModel(home: home, reader: reader)

        model.navigate(to: slow)
        model.navigate(to: quick)
        await settle(model)
        reader.release()
        for _ in 0 ..< 200 {
            await Task.yield()
        }

        XCTAssertEqual(model.directory.path, quick.path)
        XCTAssertEqual(model.entries.map(\.name), ["fresh"])
    }

    func testAnUntouchedProtectedDirectoryStillReflectsTheLiveProbe() async {
        let fixture = protectedFixture(readable: true)

        fixture.model.start()
        await settle(fixture.model)

        XCTAssertEqual(fixture.model.entries.first { $0.name == "Documents" }?.isBlocked, false)
        XCTAssertEqual(fixture.probes.probed, [home.appending(path: "Documents").path])
        XCTAssertEqual(fixture.reader.readPaths, [home.path])
    }

    func testAnUntouchedProtectedDirectoryKeepsItsLockWhenTheProbeSaysNo() async {
        let fixture = protectedFixture(readable: false)

        fixture.model.start()
        await settle(fixture.model)

        XCTAssertEqual(fixture.model.entries.first { $0.name == "Documents" }?.isBlocked, true)
    }

    func testTheLockFollowsTheLiveProbe() async {
        let fixture = protectedFixture(readable: false)
        fixture.model.start()
        await settle(fixture.model)
        XCTAssertEqual(fixture.model.entries.first { $0.name == "Documents" }?.isBlocked, true)

        fixture.probes.setReadable(true)
        fixture.model.reload()
        await settle(fixture.model)

        XCTAssertEqual(fixture.model.entries.first { $0.name == "Documents" }?.isBlocked, false)
    }

    func testGrantingOutsideTheAppClearsTheLockWithoutEnteringTheDirectory() async {
        let documents = home.appending(path: "Documents")
        let fixture = protectedFixture(readable: false)
        fixture.model.start()
        await settle(fixture.model)

        fixture.probes.setReadable(true)
        let restarted = BrowserModel(
            home: home,
            reader: fixture.reader,
            readabilityProbe: fixture.probes.probe
        )
        restarted.start()
        await settle(restarted)

        XCTAssertEqual(restarted.entries.first { $0.name == "Documents" }?.isBlocked, false)
        XCTAssertEqual(fixture.probes.probed, [documents.path, documents.path])
    }

    func testLosingAccessAgainBringsTheLockBackOnTheNextListing() async {
        let fixture = protectedFixture(readable: true)
        fixture.model.start()
        await settle(fixture.model)
        XCTAssertEqual(fixture.model.entries.first { $0.name == "Documents" }?.isBlocked, false)

        fixture.probes.setReadable(false)
        fixture.model.reload()
        await settle(fixture.model)

        XCTAssertEqual(fixture.model.entries.first { $0.name == "Documents" }?.isBlocked, true)
    }

    func testOrdinaryDirectoriesAreNeverProbed() async {
        let fixture = protectedFixture(readable: true)

        fixture.model.start()
        await settle(fixture.model)

        XCTAssertFalse(fixture.probes.probed.contains(home.appending(path: "Public").path))
        XCTAssertEqual(fixture.model.entries.first { $0.name == "Public" }?.isBlocked, false)
    }

    func testActionTargetFollowsTheSelectionAndFallsBackToTheDirectory() async {
        let reader = FakeReader()
        reader.entries[home] = [entry("Gallery", in: home)]
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)

        XCTAssertEqual(model.actionTarget.path, home.appending(path: "Gallery").path)
        XCTAssertTrue(model.actionTargetIsDirectory)

        reader.entries[home] = []
        model.navigate(to: home)
        await settle(model)

        XCTAssertEqual(model.actionTarget.path, home.path)
        XCTAssertTrue(model.actionTargetIsDirectory)
    }

    func testRefreshingKeepsWhatIsOnScreenInsteadOfBlankingIt() async {
        let reader = FakeReader()
        let child = home.appending(path: "Gallery")
        reader.entries[home] = [entry("a", in: home), entry("b", in: home)]
        reader.entries[child] = [entry("vendor", in: child)]
        let model = BrowserModel(home: home, reader: reader)
        model.start()
        await settle(model)

        model.reload()
        XCTAssertEqual(model.entries.map(\.name), ["a", "b"], "就地重读不该先把列表清空")
        if case .loading = model.state {
            XCTFail("就地重读不该把面板打回加载态——面板高度会跟着塌一下")
        }

        model.navigate(to: home)
        XCTAssertEqual(model.entries.map(\.name), ["a", "b"], "导航到已经在的目录同样是就地重读")

        model.navigate(to: child)
        XCTAssertTrue(model.entries.isEmpty, "换到别的目录才该清空，旧内容留着会对不上面包屑")
        await settle(model)
        XCTAssertEqual(model.entries.map(\.name), ["vendor"])
    }

    private func protectedFixture(
        readable: Bool
    ) -> (
        model: BrowserModel,
        reader: RecordingReader,
        documents: URL,
        probes: Probes
    ) {
        let documents = home.appending(path: "Documents")
        let reader = RecordingReader(entries: [
            home: [
                DirectoryEntry(
                    url: documents,
                    name: "Documents",
                    isDirectory: true,
                    isBlocked: true
                ),
                entry("Public", in: home),
            ],
            documents: [entry("notes", in: documents)],
        ])
        if !readable {
            reader.failures[documents] = NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadNoPermissionError
            )
        }
        let probes = Probes(readable: readable)
        let model = BrowserModel(home: home, reader: reader, readabilityProbe: probes.probe)
        return (model, reader, documents, probes)
    }

    private func entry(
        _ name: String,
        in parent: URL,
        isDirectory: Bool = true,
        hidden: Bool = false
    ) -> DirectoryEntry {
        let leaf = hidden ? "." + name : name
        return DirectoryEntry(
            url: parent.appending(path: leaf),
            name: leaf,
            isDirectory: isDirectory
        )
    }

    private func settle(_ model: BrowserModel) async {
        for _ in 0 ..< 200 {
            if case .loading = model.state {
                await Task.yield()
                continue
            }
            break
        }
        for _ in 0 ..< 40 {
            guard let pending = model.pendingLoad else {
                return
            }
            await pending.value
            await Task.yield()
            if pending.isCancelled == false {
                return
            }
        }
    }
}

private final class FakeReader: DirectoryReading, @unchecked Sendable {
    var entries = [URL: [DirectoryEntry]]()
    var failures = [URL: Error]()
    var progressReports = [URL: [(Int, Int)]]()
    var gated = Set<URL>()

    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var progress = [String]()

    var observedProgress: [String] {
        lock.withLock { progress }
    }

    func release() {
        gate.signal()
    }

    func read(
        _ url: URL,
        home _: URL,
        onProgress: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        for report in progressReports[url] ?? [] {
            lock.withLock { progress.append("\(report.0)/\(report.1)") }
            onProgress(report.0, report.1)
        }
        if gated.contains(url) {
            gate.wait()
        }
        if let failure = failures[url] {
            throw failure
        }
        return entries[url] ?? []
    }
}

private final class RecordingReader: DirectoryReading, @unchecked Sendable {
    var entries: [URL: [DirectoryEntry]]
    var failures = [URL: Error]()

    private let lock = NSLock()
    private var reads = [String]()

    var readPaths: [String] {
        lock.withLock { reads }
    }

    init(entries: [URL: [DirectoryEntry]]) {
        self.entries = entries
    }

    func read(
        _ url: URL,
        home _: URL,
        onProgress _: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        lock.withLock { reads.append(url.path) }
        if let failure = failures[url] {
            throw failure
        }
        return entries[url] ?? []
    }
}

private final class Probes: @unchecked Sendable {
    private let lock = NSLock()
    private var readable: Bool
    private var seen = [String]()

    var probed: [String] {
        lock.withLock { seen }
    }

    var probe: @Sendable (URL) -> Bool {
        { [self] url in
            lock.withLock {
                seen.append(url.standardizedFileURL.path)
                return readable
            }
        }
    }

    init(readable: Bool) {
        self.readable = readable
    }

    func setReadable(_ value: Bool) {
        lock.withLock { readable = value }
    }
}
