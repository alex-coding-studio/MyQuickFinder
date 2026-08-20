import AppKit
import MyQuickFinderKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let services = AppServices()
    let settings = SettingsPresenter()

    private var statusItem: StatusItemController?
    private var controller: PanelController?

    func applicationDidFinishLaunching(_: Notification) {
        services.appearance.activate()
        services.language.activate()
        let controller = AppComposition.makePanelController(
            bindings: services.keyBindings,
            settings: settings
        )
        self.controller = controller

        let statusItem = StatusItemController(
            onToggle: { [weak controller] item in controller?.toggle(from: item) },
            onHide: { [weak controller] in controller?.hide() },
            onOpenSettings: { [weak self] in
                self?.services.loginItem.refresh()
                self?.settings.present()
            }
        )
        self.statusItem = statusItem

        services.onHotKeyPressed = { [weak statusItem] in statusItem?.toggle() }
        let registered = services.hotKeySettings.activateStoredBinding()
        let label = HotKeyLabel.text(for: services.hotKeySettings.binding)
        statusItem.setToolTip(
            registered
                ? String(localized: "menubar.tooltip \(label)")
                : String(localized: "menubar.tooltip.conflict \(label)")
        )
    }

    func applicationWillTerminate(_: Notification) {
        services.hotKey.unregister()
    }
}
