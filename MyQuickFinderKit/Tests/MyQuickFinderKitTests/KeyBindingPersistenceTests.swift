import Foundation
import XCTest
@testable import MyQuickFinderKit

final class KeyBindingPersistenceTests: XCTestCase {
    private let newChord = KeyChord(.character("y"), [.command, .shift])

    func testAChordSurvivesAWriteAndRead() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "mqf-bindings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = KeyBindingFileStorage(url: url)

        try storage.save([.toggleFavorite: newChord])

        XCTAssertEqual(KeyBindingFileStorage(url: url).load(), [.toggleFavorite: newChord])
    }

    func testEveryKindOfChordRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "mqf-bindings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = KeyBindingFileStorage(url: url)
        let saved: [PanelCommand: KeyChord] = [
            .toggleFavorite: KeyChord(.character("y"), .command),
            .toggleHidden: KeyChord(.up, [.command, .option, .shift]),
            .openAncestors: KeyChord(.tab, .control),
        ]

        try storage.save(saved)

        XCTAssertEqual(KeyBindingFileStorage(url: url).load(), saved)
    }

    func testGarbageOnDiskFallsBackToDefaults() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "mqf-bindings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)

        XCTAssertTrue(KeyBindingFileStorage(url: url).load().isEmpty)
        XCTAssertEqual(KeyBindings.resolving([:]), .default)
    }

    func testAnOverrideForACommandThatIsNotAllowedToChangeIsIgnored() {
        let resolved = KeyBindings.resolving([.dismissPanel: newChord])

        XCTAssertEqual(
            resolved.chord(for: .dismissPanel),
            KeyBindings.default.chord(for: .dismissPanel),
            "旧版本存下的、或手改配置文件塞进来的越权覆盖，不该生效"
        )
    }

    func testAnOverrideThatWouldCollideWithAnotherCommandIsIgnored() throws {
        let taken = try XCTUnwrap(KeyBindings.default.chord(for: .toggleHidden))

        let resolved = KeyBindings.resolving([.toggleFavorite: taken])

        XCTAssertEqual(
            resolved.chord(for: .toggleFavorite),
            KeyBindings.default.chord(for: .toggleFavorite),
            "配置文件里的冲突不能让两个命令抢同一个键——界面挡得住，文件挡不住"
        )
    }

    func testAResolvedOverrideActuallyChangesBehaviour() {
        let resolved = KeyBindings.resolving([.toggleFavorite: newChord])
        let context = PanelInputContext(surface: .browse)

        XCTAssertEqual(
            PanelKeyMap.resolve(newChord, in: context, bindings: resolved),
            .intent(.toggleFavorite)
        )
        XCTAssertEqual(
            PanelKeyMap.resolve(
                KeyChord(.character("d"), .command),
                in: context,
                bindings: resolved
            ),
            .pass,
            "默认键位要让出来"
        )
    }
}
