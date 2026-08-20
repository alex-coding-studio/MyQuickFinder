import AppKit
import Foundation

@MainActor
final class StatusItemController: NSObject {
    private static let menuBarImageName = "menubarTemplate"

    private let item: NSStatusItem
    private let onToggle: (NSStatusItem) -> Void
    private let onHide: () -> Void
    private let onOpenSettings: () -> Void

    init(
        onToggle: @escaping (NSStatusItem) -> Void,
        onHide: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggle = onToggle
        self.onHide = onHide
        self.onOpenSettings = onOpenSettings
        super.init()

        let icon = NSImage(named: Self.menuBarImageName)
        icon?.accessibilityDescription = String(localized: "a11y.menubar.icon")
        item.button?.image = icon
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func setToolTip(_ text: String) {
        item.button?.toolTip = text
    }

    func toggle() {
        onToggle(item)
    }

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else {
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            presentMenu()
        } else {
            onToggle(item)
        }
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    private func presentMenu() {
        onHide()
        let menu = NSMenu()
        menu.addItem(
            withTitle: String(localized: "menu.settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(
            withTitle: String(localized: "menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }
}
