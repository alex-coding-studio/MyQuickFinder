import AppKit
import MyQuickFinderKit

@MainActor
@Observable
final class AppearanceSettings {
    private(set) var appearance: Appearance

    private let storage: any AppearanceStoring

    init(storage: any AppearanceStoring) {
        self.storage = storage
        appearance = storage.load()
    }

    func activate() {
        apply(appearance)
    }

    func select(_ selected: Appearance) {
        guard selected != appearance else {
            return
        }
        appearance = selected
        try? storage.save(selected)
        apply(selected)
    }

    private func apply(_ selected: Appearance) {
        switch selected {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
