import AppKit
import SwiftUI

@MainActor
final class SettingsPresenter {
    struct Effects: Sendable {
        static let system = Effects(
            setActivationPolicy: { policy in _ = NSApp.setActivationPolicy(policy) },
            activateApp: { NSApp.activate(ignoringOtherApps: true) },
            openSettings: {
                NSApp.sendAction(SettingsPresenter.openSelector, to: nil, from: nil)
            },
            focus: { window in
                window.center()
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        )

        var setActivationPolicy: @MainActor @Sendable (NSApplication.ActivationPolicy) -> Void
        var activateApp: @MainActor @Sendable () -> Void
        var openSettings: @MainActor @Sendable () -> Void
        var focus: @MainActor @Sendable (NSWindow) -> Void
    }

    private static let openSelector = Selector(("showSettingsWindow:"))

    private let effects: Effects
    private weak var window: NSWindow?
    private var observer: (any NSObjectProtocol)?
    private var wantsFocus = false

    init(effects: Effects = .system) {
        self.effects = effects
    }

    func present(using openSettings: (() -> Void)? = nil) {
        effects.setActivationPolicy(.regular)
        effects.activateApp()
        wantsFocus = true
        (openSettings ?? effects.openSettings)()
        focusIfPossible()
    }

    func adopt(_ candidate: NSWindow) {
        if window !== candidate {
            window = candidate
            observeClosing(of: candidate)
        }
        focusIfPossible()
    }

    private func focusIfPossible() {
        guard wantsFocus, let window else {
            return
        }
        wantsFocus = false
        effects.focus(window)
    }

    private func observeClosing(of window: NSWindow) {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [effects] _ in
            MainActor.assumeIsolated {
                effects.setActivationPolicy(.accessory)
            }
        }
    }
}

private final class WindowAdoptingView: NSView {
    var onWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            return
        }
        onWindow?(window)
    }
}

struct SettingsWindowAccessor: NSViewRepresentable {
    let presenter: SettingsPresenter

    func makeNSView(context _: Context) -> NSView {
        let view = WindowAdoptingView()
        view.onWindow = { [presenter] window in presenter.adopt(window) }
        return view
    }

    func updateNSView(_ view: NSView, context _: Context) {
        guard let window = view.window else {
            return
        }
        presenter.adopt(window)
    }
}
