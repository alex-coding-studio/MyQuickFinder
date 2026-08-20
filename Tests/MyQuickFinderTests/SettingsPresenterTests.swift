import AppKit
import XCTest
@testable import MyQuickFinder

@MainActor
final class SettingsPresenterTests: XCTestCase {
    @MainActor
    private final class Recorder {
        var policies = [NSApplication.ActivationPolicy]()
        var activations = 0
        var systemOpens = 0
        var focused = [NSWindow]()

        var effects: SettingsPresenter.Effects {
            SettingsPresenter.Effects(
                setActivationPolicy: { [self] policy in policies.append(policy) },
                activateApp: { [self] in activations += 1 },
                openSettings: { [self] in systemOpens += 1 },
                focus: { [self] window in focused.append(window) }
            )
        }
    }

    func testOpeningSettingsTurnsTheAccessoryAppIntoARegularOne() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)

        presenter.present()

        XCTAssertEqual(recorder.policies, [.regular], "LSUIElement 应用不切 .regular 就会一失焦找不回来")
        XCTAssertEqual(recorder.activations, 1)
        XCTAssertEqual(recorder.systemOpens, 1)
    }

    func testAnExplicitOpenActionReplacesTheSystemOne() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)
        var opened = 0

        presenter.present(using: { opened += 1 })

        XCTAssertEqual(opened, 1)
        XCTAssertEqual(recorder.systemOpens, 0)
    }

    func testTheWindowIsFocusedTheMomentItShowsUp() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)
        let window = NSWindow()

        presenter.present()
        XCTAssertTrue(recorder.focused.isEmpty, "窗口还没装上，这时候没有可聚焦的对象")

        presenter.adopt(window)

        XCTAssertEqual(recorder.focused.count, 1)
        XCTAssertTrue(recorder.focused.first === window)
    }

    func testAdoptingTheSameWindowAgainDoesNotStealFocusBack() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)
        let window = NSWindow()

        presenter.present()
        presenter.adopt(window)
        presenter.adopt(window)
        presenter.adopt(window)

        XCTAssertEqual(recorder.focused.count, 1, "只有 present 才表达「把窗口拿到前面来」")
    }

    func testASecondPresentFocusesTheAlreadyAdoptedWindowRightAway() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)
        let window = NSWindow()

        presenter.present()
        presenter.adopt(window)
        presenter.present()

        XCTAssertEqual(recorder.focused.count, 2)
        XCTAssertEqual(recorder.policies, [.regular, .regular])
    }

    func testClosingTheSettingsWindowPutsTheAppBackInTheMenuBar() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)
        let window = NSWindow()

        presenter.present()
        presenter.adopt(window)
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(recorder.policies, [.regular, .accessory])
    }

    func testAnotherWindowClosingDoesNotDropTheAppBackToAccessory() {
        let recorder = Recorder()
        let presenter = SettingsPresenter(effects: recorder.effects)
        let window = NSWindow()
        let unrelated = NSWindow()

        presenter.present()
        presenter.adopt(window)
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: unrelated)

        XCTAssertEqual(recorder.policies, [.regular])
    }
}
