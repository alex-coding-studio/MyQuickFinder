import SwiftUI

@main
struct MyQuickFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsScreen(
                loginItem: delegate.services.loginItem,
                appearance: delegate.services.appearance,
                language: delegate.services.language,
                hotKey: delegate.services.hotKeySettings,
                keyBindings: delegate.services.keyBindings,
                presenter: delegate.settings
            )
        }
    }
}
