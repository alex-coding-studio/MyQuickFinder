import Foundation

enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case chinese
    case english

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .chinese: "zh-Hans"
        case .english: "en"
        }
    }

    static func matching(localeIdentifier: String?) -> AppLanguage {
        allCases.first { $0.localeIdentifier == localeIdentifier } ?? .system
    }
}

@MainActor
@Observable
final class LanguageSettings {
    static let selectionKey = "AppLanguage"
    static let systemKey = "AppleLanguages"

    private(set) var language: AppLanguage

    private let defaults: UserDefaults
    private let launched: AppLanguage

    var needsRelaunch: Bool {
        language != launched
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = AppLanguage(rawValue: defaults.string(forKey: Self.selectionKey) ?? "")
        let resolved = stored ?? AppLanguage.system
        language = resolved
        launched = resolved
    }

    func activate() {
        apply(language)
    }

    func select(_ selected: AppLanguage) {
        guard selected != language else {
            return
        }
        language = selected
        defaults.set(selected.rawValue, forKey: Self.selectionKey)
        apply(selected)
    }

    private func apply(_ selected: AppLanguage) {
        guard let identifier = selected.localeIdentifier else {
            defaults.removeObject(forKey: Self.systemKey)
            return
        }
        defaults.set([identifier], forKey: Self.systemKey)
    }
}
