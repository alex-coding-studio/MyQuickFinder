import Foundation
@testable import MyQuickFinderKit

@MainActor
enum PanelFixture {
    static let home = URL(fileURLWithPath: "/tmp/qf-home")

    static func entry(
        _ name: String,
        in parent: URL,
        isDirectory: Bool = true
    ) -> DirectoryEntry {
        DirectoryEntry(url: parent.appending(path: name), name: name, isDirectory: isDirectory)
    }

    static func denialError() -> Error {
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
    }

    static func make(
        entries: [URL: [DirectoryEntry]],
        failing: [URL: Error] = [:]
    ) -> PanelModel {
        let reader = FixtureReader(entries: entries, failures: failing)
        return PanelModel(
            browser: BrowserModel(home: home, reader: reader, readabilityProbe: { _ in true }),
            picker: PathPickerModel(home: home, reader: reader, readabilityProbe: { _ in true }),
            storage: InMemoryFavoriteStorage()
        )
    }

    static func settle(_ model: PanelModel) async {
        for _ in 0 ..< 200 {
            if case .loading = model.browser.state {
                await Task.yield()
                continue
            }
            break
        }
        for _ in 0 ..< 40 {
            guard let pending = model.browser.pendingLoad else {
                return
            }
            await pending.value
            await Task.yield()
            if pending.isCancelled == false {
                return
            }
        }
    }

    static func settlePicker(_ model: PanelModel) async {
        for _ in 0 ..< 20 {
            guard let pending = model.picker.pendingLoad else {
                return
            }
            await pending.value
            await Task.yield()
            if model.picker.pendingLoad == nil || model.picker.pendingLoad?.isCancelled == true {
                return
            }
            if pending.isCancelled == false {
                return
            }
        }
    }
}

struct FixtureReader: DirectoryReading {
    private let listings: [String: [DirectoryEntry]]
    private let failures: [String: Error]

    init(entries: [URL: [DirectoryEntry]], failures: [URL: Error]) {
        listings = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.key.standardizedFileURL.path, $0.value) }
        )
        self.failures = Dictionary(
            uniqueKeysWithValues: failures.map { ($0.key.standardizedFileURL.path, $0.value) }
        )
    }

    func read(
        _ url: URL,
        home _: URL,
        onProgress _: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        let key = url.standardizedFileURL.path
        if let failure = failures[key] {
            throw failure
        }
        guard let listed = listings[key] else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
        }
        return listed
    }
}
