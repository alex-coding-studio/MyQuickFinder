import Foundation
import XCTest
@testable import MyQuickFinderKit

@MainActor
final class PanelInvariantTests: XCTestCase {
    private static let sequences: [[PanelIntent]] = [
        [.moveSelection(1), .enterSelection, .goToParent, .moveSelection(-1)],
        [.switchZone, .moveSelection(1), .switchZone, .moveSelection(1)],
        [.openPicker, .moveSelection(1), .exitPicker, .moveSelection(1)],
        [.openPicker, .toggleFavorite, .exitPicker, .switchZone, .toggleFavorite],
        [.toggleFavorite, .switchZone, .moveSelection(5), .moveSelection(-5), .switchZone],
        [.toggleHidden, .moveSelection(3), .toggleHidden, .enterSelection, .goToParent],
        [.openAncestors, .moveAncestorSelection(-1), .confirmAncestor, .moveSelection(1)],
        [.showHelp, .moveSelection(1), .hideHelp, .openPicker, .clearPickerText, .exitPicker],
        [.moveSelection(9999), .moveSelection(-9999), .enterSelection, .moveSelection(1)],
        [.switchZone, .toggleFavorite, .moveSelection(1), .switchZone, .enterSelection],
    ]

    private static let ancestorSequences: [[PanelIntent]] = [
        [.enterSelection, .enterSelection, .openAncestors, .confirmAncestor],
        [.enterSelection, .openAncestors, .moveAncestorSelection(-1), .confirmAncestor],
        [
            .enterSelection,
            .enterSelection,
            .openAncestors,
            .moveAncestorSelection(-9),
            .confirmAncestor,
        ],
        [.enterSelection, .openAncestors, .goToParent, .confirmAncestor],
        [.enterSelection, .enterSelection, .openAncestors, .moveSelection(1), .confirmAncestor],
        [.enterSelection, .openAncestors, .openPicker, .exitPicker, .confirmAncestor],
    ]

    private let home = URL(fileURLWithPath: "/tmp/qf-home")

    func testSelectionNeverPointsOutsideTheList() async {
        for sequence in Self.sequences {
            let model = await primed()
            for intent in sequence {
                model.perform(intent)
                await settle(model)
                let entries = model.browser.entries
                XCTAssertTrue(
                    entries.isEmpty || entries.indices.contains(model.browser.selectionIndex),
                    "\(sequence) 之后选中索引跑出了列表"
                )
                let results = model.picker.entries
                XCTAssertTrue(
                    results.isEmpty || results.indices.contains(model.picker.selectionIndex),
                    "\(sequence) 之后路径栏选中索引跑出了结果"
                )
            }
        }
    }

    func testOnlyOneRegionEverShowsASelection() async {
        for sequence in Self.sequences {
            let model = await primed()
            for intent in sequence {
                model.perform(intent)
                await settle(model)
                let inList = model.listSelectionIsActive
                let inFavorites = model.favoritesSelectionIsActive
                XCTAssertFalse(inList && inFavorites, "\(sequence) 之后两个区同时亮着")
                if model.isPicking {
                    XCTAssertFalse(
                        inList || inFavorites,
                        "\(sequence) 之后路径栏开着，浏览区和收藏栏都不该有填充"
                    )
                }
            }
        }
    }

    func testTheKeyboardOnlyEverBecomesEngaged() async {
        for sequence in Self.sequences {
            let model = await primed()
            var engaged = false
            for intent in sequence {
                model.perform(intent)
                await settle(model)
                if engaged {
                    XCTAssertTrue(
                        model.browser.keyboardEngaged,
                        "\(sequence) 里 \(intent) 之后选中态退回了灰色"
                    )
                }
                engaged = model.browser.keyboardEngaged
            }
        }
    }

    func testEveryEffectCarriesTheTargetThatWasCurrentWhenItFired() async {
        for sequence in Self.sequences {
            let model = await primed()
            for intent in sequence {
                model.perform(intent)
                await settle(model)
                assertActionsMatchTarget(model, after: sequence)
            }
        }
    }

    func testWhateverIsHighlightedIsExactlyWhatTheActionsWillHit() async {
        for sequence in Self.sequences {
            let model = await primed()
            for intent in sequence {
                model.perform(intent)
                await settle(model)
                assertHighlightMatchesTarget(model, after: sequence)
            }
        }
    }

    func testThePathBarNeverLosesFocusWhileItIsStillOpen() async {
        for sequence in Self.sequences {
            let model = await primed()
            for intent in sequence {
                let wasPicking = model.isPicking
                let effects = model.perform(intent)
                await settle(model)
                guard wasPicking, model.isPicking else {
                    continue
                }
                let openedOverlay = model.showsHelp || model.showsAncestors
                XCTAssertFalse(
                    effects.contains(.focusPanel) && !openedOverlay,
                    "\(sequence) 里 \(intent) 之后路径栏还开着，却把焦点交给了面板"
                )
            }
        }
    }

    func testTheAncestorMenuNeverHighlightsARowThatIsNotThere() async {
        for sequence in Self.sequences + Self.ancestorSequences {
            let model = await primed()
            for intent in sequence {
                model.perform(intent)
                await settle(model)
                guard model.showsAncestors else {
                    continue
                }
                XCTAssertTrue(
                    model.ancestors.indices.contains(model.ancestorIndex),
                    "\(sequence)：祖先菜单亮着第 \(model.ancestorIndex) 层，可它只有 \(model.ancestors.count) 层"
                )
            }
        }
    }

    func testConfirmingAlwaysLandsOnTheAncestorThatWasHighlighted() async {
        for sequence in Self.ancestorSequences {
            let model = await primed()
            for intent in sequence {
                if case .confirmAncestor = intent, model.showsAncestors {
                    let expected = model.ancestors[model.ancestorIndex].url
                    model.perform(intent)
                    await settle(model)
                    XCTAssertEqual(
                        model.browser.directory,
                        expected,
                        "\(sequence)：确认之后到的不是刚才亮着的那一层"
                    )
                    continue
                }
                model.perform(intent)
                await settle(model)
            }
        }
    }

    private func assertHighlightMatchesTarget(_ model: PanelModel, after sequence: [PanelIntent]) {
        if model.isPicking {
            guard let index = model.picker.highlightedIndex else {
                XCTAssertEqual(
                    model.actionTarget,
                    model.picker.resolvedDirectory,
                    "\(sequence)：路径栏一行都没亮，动作就该落在框里那个目录上"
                )
                return
            }
            XCTAssertEqual(
                model.actionTarget,
                model.picker.entries[index].url,
                "\(sequence)：路径栏亮着一行，动作却落在别处"
            )
            return
        }
        if let favorite = model.focusedFavorite {
            XCTAssertEqual(
                model.actionTarget,
                favorite.url,
                "\(sequence)：收藏项亮着，动作却落在浏览区的某一行上"
            )
            return
        }
        XCTAssertTrue(
            model.listSelectionIsActive,
            "\(sequence)：收藏区没有选中项，焦点就该落回列表，不能两个区都不亮"
        )
        guard let entry = model.browser.selectedEntry else {
            return
        }
        XCTAssertEqual(
            model.actionTarget,
            entry.url,
            "\(sequence)：浏览区亮着一行，动作却落在别处"
        )
    }

    private func assertActionsMatchTarget(_ model: PanelModel, after sequence: [PanelIntent]) {
        let target = model.actionTarget
        let isDirectory = model.actionTargetIsDirectory
        let canAct = model.canActOnTarget

        XCTAssertEqual(
            model.perform(.openInFinder),
            [.revealInFinder(target, isDirectory: isDirectory), .dismiss],
            "\(sequence) 之后 Finder 动作打开的不是当前目标"
        )
        let terminal = model.perform(.openInTerminal)
        let expectedTerminal: [PanelEffect] = canAct
            ? [
                .openInTerminal(TerminalTarget.directory(for: target, isDirectory: isDirectory)),
                .dismiss,
            ]
            : []
        XCTAssertEqual(terminal, expectedTerminal, "\(sequence) 之后终端动作对不上当前目标")
        XCTAssertEqual(
            model.perform(.copyPath),
            canAct ? [.copyPath(target), .dismiss] : [],
            "\(sequence) 之后复制的不是当前目标"
        )
    }

    private func primed() async -> PanelModel {
        let studio = home.appending(path: "code-studio")
        let reader = InvariantStubReader(entries: [
            home: [
                DirectoryEntry(url: studio, name: "code-studio", isDirectory: true),
                DirectoryEntry(
                    url: home.appending(path: "notes"),
                    name: "notes",
                    isDirectory: true
                ),
                DirectoryEntry(
                    url: home.appending(path: ".hidden"),
                    name: ".hidden",
                    isDirectory: true
                ),
            ],
            studio: [
                DirectoryEntry(
                    url: studio.appending(path: "MyQuickFinder"),
                    name: "MyQuickFinder",
                    isDirectory: true
                ),
            ],
            home.appending(path: "notes"): [],
            home.appending(path: ".hidden"): [],
            studio.appending(path: "MyQuickFinder"): [],
            URL(fileURLWithPath: "/tmp"): [],
        ])
        let model = PanelModel(
            browser: BrowserModel(home: home, reader: reader, readabilityProbe: { _ in true }),
            picker: PathPickerModel(home: home, reader: reader, readabilityProbe: { _ in true }),
            storage: InMemoryFavoriteStorage()
        )
        model.browser.start()
        await settle(model)
        return model
    }

    private func settle(_ model: PanelModel) async {
        for _ in 0 ..< 200 {
            if case .loading = model.browser.state {
                await Task.yield()
                continue
            }
            break
        }
        for _ in 0 ..< 40 {
            guard let pending = model.browser.pendingLoad else {
                break
            }
            await pending.value
            await Task.yield()
            if pending.isCancelled == false {
                break
            }
        }
        for _ in 0 ..< 20 {
            guard let pending = model.picker.pendingLoad else {
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

private struct InvariantStubReader: DirectoryReading {
    private let listings: [String: [DirectoryEntry]]

    init(entries: [URL: [DirectoryEntry]]) {
        listings = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.key.standardizedFileURL.path, $0.value) }
        )
    }

    func read(
        _ url: URL,
        home _: URL,
        onProgress _: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        guard let listed = listings[url.standardizedFileURL.path] else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
        }
        return listed
    }
}
