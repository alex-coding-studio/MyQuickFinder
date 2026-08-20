import AppKit
import MyQuickFinderKit

@MainActor
@Observable
final class HotKeySettings {
    private(set) var binding: HotKeyBinding
    private(set) var registrationFailed = false

    private let storage: any HotKeyStoring
    private let apply: (HotKeyBinding) -> Bool

    init(storage: any HotKeyStoring, apply: @escaping (HotKeyBinding) -> Bool) {
        self.storage = storage
        self.apply = apply
        binding = storage.load()
    }

    @discardableResult
    func activateStoredBinding() -> Bool {
        registrationFailed = !apply(binding)
        return !registrationFailed
    }

    func record(_ newBinding: HotKeyBinding) {
        let previous = binding
        binding = newBinding
        guard apply(newBinding) else {
            registrationFailed = true
            binding = previous
            _ = apply(previous)
            return
        }
        registrationFailed = false
        try? storage.save(newBinding)
    }
}

@MainActor
final class AppServices {
    static let storageDirectoryName = "MyQuickFinder"

    let hotKey: GlobalHotKey
    let loginItem: LoginItemSettings
    let hotKeySettings: HotKeySettings
    let appearance: AppearanceSettings
    let language: LanguageSettings
    let keyBindings: KeyBindingStore

    var onHotKeyPressed: (() -> Void)?

    init() {
        let hotKey = GlobalHotKey()
        self.hotKey = hotKey
        loginItem = LoginItemSettings()
        appearance = AppearanceSettings(
            storage: AppearanceFileStorage(directoryName: Self.storageDirectoryName)
        )
        language = LanguageSettings()
        keyBindings = KeyBindingStore(
            storage: KeyBindingFileStorage(directoryName: Self.storageDirectoryName)
        )

        var pressed: (() -> Void)?
        hotKeySettings = HotKeySettings(
            storage: HotKeyFileStorage(
                directoryName: Self.storageDirectoryName,
                fallback: .optionSpace
            ),
            apply: { binding in
                hotKey.register(keyCode: binding.keyCode, modifiers: binding.carbonModifiers) {
                    pressed?()
                }
            }
        )
        pressed = { [weak self] in self?.onHotKeyPressed?() }
    }
}
