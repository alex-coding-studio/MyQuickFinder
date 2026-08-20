import MyQuickFinderKit

struct PanelEffectRunner {
    let terminal: any TerminalLauncher
    let onDismiss: () -> Void
    let setPanelFocus: (Bool) -> Void

    func run(_ effects: [PanelEffect]) {
        for effect in effects {
            apply(effect)
        }
    }

    private func apply(_ effect: PanelEffect) {
        switch effect {
        case let .revealInFinder(url, isDirectory):
            SystemActions.revealInFinder(url, isDirectory: isDirectory)
        case let .openInTerminal(url):
            try? terminal.open(url)
        case let .copyPath(url):
            SystemActions.copyPath(url)
        case .dismiss:
            onDismiss()
        case .focusPathField:
            setPanelFocus(false)
            PanelKeyboard.focusPathField()
        case .moveCaretToPathEnd:
            PanelKeyboard.moveCaretToPathEnd()
        case .focusPanel:
            setPanelFocus(true)
        }
    }
}
