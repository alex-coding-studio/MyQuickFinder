import MyQuickFinderKit
import SwiftUI

struct GeneralSettings: View {
    private static let appearanceLabels: [Appearance: String] = [
        .system: String(localized: "settings.appearance.system"),
        .light: String(localized: "settings.appearance.light"),
        .dark: String(localized: "settings.appearance.dark"),
    ]

    private static let languageLabels: [AppLanguage: String] = [
        .system: String(localized: "settings.language.system"),
        .chinese: String(localized: "settings.language.chinese"),
        .english: String(localized: "settings.language.english"),
    ]

    let loginItem: LoginItemSettings
    let appearance: AppearanceSettings
    let language: LanguageSettings

    private var loginItemMessage: String {
        if let failure = loginItem.failureMessage {
            return failure
        }
        if loginItem.isEnabled {
            return String(localized: "settings.launch.enabled")
        }
        return String(localized: "settings.launch.disabled")
    }

    private var languageMessage: String {
        if language.needsRelaunch {
            return String(localized: "settings.language.pending")
        }
        return String(localized: "settings.language.note")
    }

    var body: some View {
        SettingsSection {
            Section {
                Toggle("settings.launch.toggle", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.needsApproval {
                    Button("settings.launch.open") {
                        loginItem.openLoginItemsSettings()
                    }
                }
            } footer: {
                SettingsNote(loginItemMessage, isWarning: loginItem.failureMessage != nil)
            }

            Section {
                Picker("settings.appearance.title", selection: Binding(
                    get: { appearance.appearance },
                    set: { appearance.select($0) }
                )) {
                    ForEach(Appearance.allCases, id: \.self) { option in
                        Text(Self.appearanceLabels[option] ?? "").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            } footer: {
                SettingsNote(String(localized: "settings.appearance.note"))
            }

            Section {
                Picker("settings.language.title", selection: Binding(
                    get: { language.language },
                    set: { language.select($0) }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { option in
                        Text(Self.languageLabels[option] ?? "").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                if language.needsRelaunch {
                    Button("settings.language.relaunch") {
                        SystemActions.relaunch()
                    }
                }
            } footer: {
                SettingsNote(languageMessage)
            }

            Section {
                LabeledContent("settings.version.title", value: AppVersion.display)
            } footer: {
                SettingsNote(String(localized: "settings.version.note"))
            }
        }
        .onAppear { loginItem.refresh() }
    }
}
