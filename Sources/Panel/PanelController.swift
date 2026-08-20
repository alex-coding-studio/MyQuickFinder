import AppKit
import MyQuickFinderKit
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: KeyablePanel
    private let model: PanelModel
    private var dismissGeneration = 0

    var isVisible: Bool {
        panel.isVisible
    }

    init(
        model: PanelModel,
        terminal: any TerminalLauncher,
        bindings: KeyBindingStore,
        settings: SettingsPresenter
    ) {
        self.model = model
        panel = KeyablePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DesignTokens.Panel.width,
                height: DesignTokens.Panel.width
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        let hosting = NSHostingView(
            rootView: PanelView(
                model: model,
                terminal: terminal,
                bindings: bindings,
                settings: settings,
                onDismiss: { [weak self] in self?.hide() },
                onContentHeightChange: { [weak self] height in self?.resize(
                    toContentHeight: height
                ) }
            )
        )
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: DesignTokens.Panel.width,
            height: DesignTokens.Panel.width
        )

        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func toggle(from statusItem: NSStatusItem) {
        isVisible ? hide() : show(from: statusItem)
    }

    func show(from statusItem: NSStatusItem) {
        model.restoreEntryPoint()
        model.markPresented()
        position(below: statusItem)
        dismissGeneration += 1
        panel.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else {
            return
        }
        dismissGeneration += 1
        let generation = dismissGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.Motion.dismiss
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, generation == self.dismissGeneration else {
                    return
                }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    func windowDidResignKey(_: Notification) {
        hide()
    }

    @objc private func applicationDidBecomeActive() {
        guard isVisible else {
            return
        }
        model.refreshAfterReturningToApp()
    }

    private func resize(toContentHeight height: CGFloat) {
        guard let frame = PanelGeometry.resizing(
            panel.frame,
            toContentHeight: height,
            width: DesignTokens.Panel.width
        ) else {
            return
        }
        panel.setFrame(frame, display: panel.isVisible)
    }

    private func position(below statusItem: NSStatusItem) {
        guard
            let button = statusItem.button,
            let buttonWindow = button.window,
            let screen = buttonWindow.screen ?? NSScreen.main
        else {
            panel.center()
            return
        }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panel.setFrameOrigin(PanelGeometry.origin(
            below: anchor,
            size: panel.frame.size,
            in: screen.visibleFrame
        ))
    }
}
