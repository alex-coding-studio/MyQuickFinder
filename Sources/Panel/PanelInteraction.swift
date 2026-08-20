import MyQuickFinderKit
import SwiftUI

@MainActor
struct PanelInteraction {
    let model: PanelModel
    let bindings: KeyBindingStore
    let terminal: any TerminalLauncher
    let settings: SettingsPresenter
    let onDismiss: () -> Void
    let setPanelFocus: (Bool) -> Void

    var actions: PanelActions {
        PanelActions(
            model: model,
            bindings: bindings.bindings,
            run: { intent in run(intent) }
        )
    }

    private var effects: PanelEffectRunner {
        PanelEffectRunner(
            terminal: terminal,
            onDismiss: onDismiss,
            setPanelFocus: setPanelFocus
        )
    }

    func run(_ intent: PanelIntent, fromKeyboard: Bool = false) {
        effects.run(model.perform(intent, fromKeyboard: fromKeyboard))
    }

    func handle(_ press: KeyPress) -> KeyPress.Result {
        let context = model.inputContext(
            isTextFieldFocused: PanelKeyboard.isPathFieldFocused,
            isComposingText: PanelKeyboard.isComposingInPathField
        )
        return resolve(
            PanelKeyboard.chord(from: press),
            in: context,
            isRepeat: press.phase == .repeat
        ) ? .handled : .ignored
    }

    func handleFieldChord(_ chord: KeyChord, _ facts: PathFieldFacts) -> Bool {
        let context = model.inputContext(isTextFieldFocused: true, field: facts)
        return resolve(chord, in: context, isRepeat: false)
    }

    func restoreFocus() {
        guard !model.isPicking else {
            setPanelFocus(false)
            PanelKeyboard.focusPathField()
            return
        }
        setPanelFocus(false)
        Task { @MainActor in
            setPanelFocus(true)
        }
    }

    func presentSettings(using openSettings: @escaping () -> Void) {
        onDismiss()
        settings.present(using: openSettings)
    }

    func openFavorite(_ id: Favorite.ID) {
        model.selectFavorite(id)
        run(.openInFinder)
    }

    func toggleFavorite(for entry: DirectoryEntry) {
        if model.favorites.contains(url: entry.url) {
            model.removeFavoriteByURL(entry.url)
        } else {
            model.addFavorite(entry)
        }
    }

    func selectRow(_ index: Int) {
        model.focusList()
        model.browser.selectRow(index)
    }

    func toggleFavorite(at index: Int) {
        model.focusList()
        model.browser.selectRow(index)
        model.toggleFavoriteForSelection()
    }

    func jump(to url: URL) {
        model.focusList()
        model.browser.navigate(to: url)
    }

    private func resolve(
        _ chord: KeyChord,
        in context: PanelInputContext,
        isRepeat: Bool
    ) -> Bool {
        switch PanelKeyMap.resolve(chord, in: context, bindings: bindings.bindings) {
        case let .intent(intent):
            if !isRepeat || intent.allowsRepeat {
                run(intent, fromKeyboard: true)
            }
            return true
        case .swallow:
            return true
        case .pass:
            return false
        }
    }
}
