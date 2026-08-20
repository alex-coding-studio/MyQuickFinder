import XCTest
@testable import MyQuickFinder

final class LocalizationTests: XCTestCase {
    func testTheAppShipsBothLanguages() throws {
        XCTAssertFalse(try keys(for: "zh-Hans").isEmpty)
        XCTAssertFalse(try keys(for: "en").isEmpty)
    }

    func testEveryChineseSourceStringHasAnEnglishTranslation() throws {
        let chinese = try keys(for: "zh-Hans")
        let english = try keys(for: "en")

        XCTAssertEqual(
            chinese.subtracting(english),
            [],
            "缺英文翻译的 key 会在英文环境里直接显示成 key 本身"
        )
        XCTAssertEqual(english.subtracting(chinese), [])
    }

    func testLookupsResolveInsteadOfFallingBackToTheKey() throws {
        for key in try keys(for: "zh-Hans") {
            XCTAssertNotEqual(
                Bundle.main.localizedString(forKey: key, value: key, table: nil),
                key,
                "\(key) 没有解析到译文"
            )
        }
    }

    func testCommandCopyReadsFromTheCatalogRatherThanTheKey() {
        for command in PanelCommandCopy.helpOrder {
            let title = PanelCommandCopy.title(command)
            XCTAssertFalse(title.isEmpty)
            XCTAssertFalse(title.hasPrefix("command."))
        }
    }

    private func strings(for language: String) throws -> Set<String> {
        let url = try XCTUnwrap(Bundle.main.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: "\(language).lproj"
        ))
        let plist = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: url),
            format: nil
        )
        return try Set(XCTUnwrap(plist as? [String: String]).keys)
    }

    private func plurals(for language: String) throws -> Set<String> {
        guard let url = Bundle.main.url(
            forResource: "Localizable",
            withExtension: "stringsdict",
            subdirectory: "\(language).lproj"
        ) else {
            return []
        }
        let plist = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: url),
            format: nil
        )
        return try Set(XCTUnwrap(plist as? [String: Any]).keys)
    }

    private func keys(for language: String) throws -> Set<String> {
        try strings(for: language).union(plurals(for: language))
    }
}
