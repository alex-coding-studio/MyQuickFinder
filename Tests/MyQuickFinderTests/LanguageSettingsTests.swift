import XCTest
@testable import MyQuickFinder

@MainActor
final class LanguageSettingsTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    private var systemPreference: [String]? {
        defaults.persistentDomain(forName: suiteName)?[LanguageSettings.systemKey] as? [String]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "LanguageSettingsTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try super.tearDownWithError()
    }

    func testAFreshInstallFollowsTheSystem() {
        let settings = LanguageSettings(defaults: defaults)

        XCTAssertEqual(settings.language, .system)
        XCTAssertFalse(settings.needsRelaunch)
        XCTAssertNil(systemPreference)
    }

    func testSelectingALanguageWritesTheSystemPreferenceMacOSReadsAtLaunch() {
        let settings = LanguageSettings(defaults: defaults)

        settings.select(.english)

        XCTAssertEqual(systemPreference, ["en"])
        XCTAssertEqual(defaults.string(forKey: LanguageSettings.selectionKey), "english")
    }

    func testTheSelectionSurvivesARestart() {
        LanguageSettings(defaults: defaults).select(.chinese)

        let restarted = LanguageSettings(defaults: defaults)

        XCTAssertEqual(restarted.language, .chinese)
        XCTAssertFalse(restarted.needsRelaunch, "重启后已经生效，不该还提示重启")
    }

    func testChangingTheLanguageAsksForARestartUntilItIsUndone() {
        let settings = LanguageSettings(defaults: defaults)

        settings.select(.english)
        XCTAssertTrue(settings.needsRelaunch)

        settings.select(.system)
        XCTAssertFalse(settings.needsRelaunch)
        XCTAssertNil(systemPreference)
    }

    func testGoingBackToTheSystemLanguageRemovesTheOverride() {
        let settings = LanguageSettings(defaults: defaults)
        settings.select(.chinese)

        settings.select(.system)

        XCTAssertNil(systemPreference)
        XCTAssertEqual(defaults.string(forKey: LanguageSettings.selectionKey), "system")
    }

    func testActivateReappliesAStoredSelectionThatLostItsSystemPreference() {
        LanguageSettings(defaults: defaults).select(.english)
        defaults.removeObject(forKey: LanguageSettings.systemKey)

        LanguageSettings(defaults: defaults).activate()

        XCTAssertEqual(systemPreference, ["en"])
    }
}
