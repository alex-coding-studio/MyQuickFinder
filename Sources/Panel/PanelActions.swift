import MyQuickFinderKit
import SwiftUI

@MainActor
struct PanelActions {
    let model: PanelModel
    let bindings: KeyBindings
    let run: (PanelIntent) -> Void

    var finder: PanelAction {
        PanelAction(
            id: "finder",
            title: model.browser.isDenied
                ? String(localized: "action.finderWhenDenied")
                : PanelCommandCopy.shortTitle(.openInFinder),
            keyCap: PanelCommandCopy.shortCap(.openInFinder, in: bindings),
            shortcut: nil,
            isPrimary: !model.browser.isDenied
        ) {
            run(.openInFinder)
        }
    }

    var bar: [PanelAction] {
        guard model.hasActionTarget, !model.isOverlayOwningKeyboard else {
            return live.map { action in
                var disabled = action
                disabled.isEnabled = false
                return disabled
            }
        }
        guard model.canActOnTarget else {
            return []
        }
        return live
    }

    private var live: [PanelAction] {
        [
            finder,
            PanelAction(
                id: "terminal",
                title: PanelCommandCopy.shortTitle(.openInTerminal),
                keyCap: PanelCommandCopy.shortCap(.openInTerminal, in: bindings),
                shortcut: nil,
                isPrimary: false
            ) {
                run(.openInTerminal)
            },
            PanelAction(
                id: "copy",
                title: PanelCommandCopy.shortTitle(.copyPath),
                keyCap: PanelCommandCopy.shortCap(.copyPath, in: bindings),
                shortcut: nil,
                isPrimary: false
            ) {
                run(.copyPath)
            },
        ]
    }
}
