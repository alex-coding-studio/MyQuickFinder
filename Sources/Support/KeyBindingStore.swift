import MyQuickFinderKit
import Observation

@MainActor
@Observable
final class KeyBindingStore {
    private(set) var bindings: KeyBindings
    private(set) var overrides: [PanelCommand: KeyChord]

    private let storage: any KeyBindingStoring

    var hasCustomBindings: Bool {
        !overrides.isEmpty
    }

    init(storage: any KeyBindingStoring) {
        let loaded = storage.load()
        self.storage = storage
        overrides = loaded
        bindings = .resolving(loaded)
    }

    @discardableResult
    func rebind(_ command: PanelCommand, to chord: KeyChord) -> PanelCommand? {
        guard command.isCustomizable else {
            return nil
        }
        if let taken = bindings.conflict(for: chord, ignoring: command) {
            return taken
        }
        overrides[command] = chord
        commit()
        return nil
    }

    func reset(_ command: PanelCommand) {
        guard overrides.removeValue(forKey: command) != nil else {
            return
        }
        commit()
    }

    func resetAll() {
        guard hasCustomBindings else {
            return
        }
        overrides = [:]
        commit()
    }

    private func commit() {
        bindings = .resolving(overrides)
        try? storage.save(overrides)
    }
}
