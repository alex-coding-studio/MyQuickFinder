import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class PickerActionTargetTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testTheActionTargetNeverLagsBehindTheTypedPath() async {
        let studio = home.appending(path: "code-studio")
        let downloads = home.appending(path: "Downloads")
        let reader = MutableReader(entries: [
            home: [entry("code-studio", in: home), entry("Downloads", in: home)],
            studio: [entry("Atlas", in: studio)],
            downloads: [],
        ])
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader),
            picker: PathPickerModel(home: home, reader: reader),
            storage: InMemoryFavoriteStorage()
        )
        model.restoreEntryPoint()
        await settle(model)
        model.browser.enterSelection()
        await settle(model)
        XCTAssertEqual(model.browser.selectedEntry?.name, "Atlas")

        model.activatePicker()
        for _ in 0 ..< 200 where model.picker.state == .loading {
            await Task.yield()
        }
        model.picker.updateText("~/Downloads")
        for _ in 0 ..< 200 where model.picker.state == .loading {
            await Task.yield()
        }

        XCTAssertEqual(model.picker.resolvedDirectory.path, downloads.path)
        XCTAssertEqual(model.actionTarget.path, downloads.path)
        XCTAssertNotEqual(model.actionTarget.path, studio.appending(path: "Atlas").path)
    }

    private func entry(_ name: String, in parent: URL, isDirectory: Bool = true) -> DirectoryEntry {
        DirectoryEntry(url: parent.appending(path: name), name: name, isDirectory: isDirectory)
    }

    private func settle(_ model: PanelModel) async {
        for _ in 0 ..< 300 {
            if model.browser.state == .loading(
                read: 0,
                total: nil
            ) || model.picker.state == .loading {
                await Task.yield()
                continue
            }
            await Task.yield()
            return
        }
    }
}

private final class MutableReader: DirectoryReading, @unchecked Sendable {
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
        let key = url.standardizedFileURL.path
        if let failure = failures.first(where: { $0.key.standardizedFileURL.path == key })?.value {
            throw failure
        }
        return entries.first(where: { $0.key.standardizedFileURL.path == key })?.value ?? []
    }
}
