import SwiftUI

struct SettingsScreen: View {
    let loginItem: LoginItemSettings
    let appearance: AppearanceSettings
    let language: LanguageSettings
    let hotKey: HotKeySettings
    let keyBindings: KeyBindingStore
    let presenter: SettingsPresenter

    var body: some View {
        TabView {
            GeneralSettings(loginItem: loginItem, appearance: appearance, language: language)
                .tabItem { Label("settings.tab.general", systemImage: "gearshape") }

            KeyBindingSettings(
                binding: hotKey.binding,
                registrationFailed: hotKey.registrationFailed,
                store: keyBindings,
                onRecord: { recorded in hotKey.record(recorded) }
            )
            .tabItem { Label("settings.tab.keys", systemImage: "keyboard") }

            HelpSettings(bindings: keyBindings.bindings)
                .tabItem { Label("settings.tab.help", systemImage: "questionmark.circle") }
        }
        .background(SettingsWindowAccessor(presenter: presenter))
    }
}
