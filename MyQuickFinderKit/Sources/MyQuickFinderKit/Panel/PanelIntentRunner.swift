import Foundation

public enum PanelEffect: Equatable, Sendable {
    case revealInFinder(URL, isDirectory: Bool)
    case openInTerminal(URL)
    case copyPath(URL)
    case dismiss
    case focusPathField
    case moveCaretToPathEnd
    case focusPanel
}

public extension PanelModel {
    func inputContext(
        isTextFieldFocused: Bool,
        field: PathFieldFacts? = nil,
        isComposingText: Bool = false
    ) -> PanelInputContext {
        PanelInputContext(
            surface: isPicking ? .picker : .browse,
            showsHelp: showsHelp,
            showsAncestors: showsAncestors,
            isTextFieldFocused: isTextFieldFocused,
            hasTextSelection: (field?.selectionLength ?? 0) > 0,
            isCaretAtEnd: field.map { $0.caretLocation >= picker.text.count } ?? true,
            isTextEmpty: picker.text.isEmpty,
            isTextPristine: picker.isPristine,
            isComposingText: field?.isComposing ?? isComposingText
        )
    }

    var isOverlayOwningKeyboard: Bool {
        showsHelp || showsAncestors
    }

    var hasActionTarget: Bool {
        picker.isActive ? picker.hasActionableTarget : true
    }

    var canActOnTarget: Bool {
        guard hasActionTarget else {
            return false
        }
        return picker.isActive ? picker.state != .denied : !browser.isDenied
    }

    @discardableResult
    func perform(_ intent: PanelIntent, fromKeyboard: Bool = false) -> [PanelEffect] {
        if fromKeyboard {
            browser.engageKeyboard()
        }
        switch intent {
        case let .moveSelection(offset):
            moveSelection(by: offset)
        case .enterSelection:
            guard zone == .list else {
                focusList()
                return []
            }
            browser.enterSelection()
        case .goToParent:
            focusList()
            browser.goUp()
        case .switchZone:
            browser.engageKeyboard()
            switchZone()
        case .toggleHidden:
            focusList()
            browser.toggleHidden()
        default:
            return performOverlay(intent)
        }
        return []
    }

    private func performOverlay(_ intent: PanelIntent) -> [PanelEffect] {
        switch intent {
        case .hideHelp:
            setHelpVisible(false)
            return picker.isActive ? [.focusPathField] : []
        case .openAncestors:
            openAncestors()
        case let .moveAncestorSelection(offset):
            moveAncestorSelection(by: offset)
        case .confirmAncestor:
            confirmAncestor()
        case .closeAncestors:
            closeAncestors()
        default:
            return performPicker(intent)
        }
        return []
    }

    private func performPicker(_ intent: PanelIntent) -> [PanelEffect] {
        switch intent {
        case .clearPickerText:
            picker.updateText("")
        case .completePath:
            completePickedPath()
        case .collapseSelectionToEnd:
            picker.markInteracted()
            return [.moveCaretToPathEnd]
        default:
            return performFocusing(intent)
        }
        return []
    }

    private func performFocusing(_ intent: PanelIntent) -> [PanelEffect] {
        switch intent {
        case let .activateFavorite(index):
            picker.deactivate()
            activateFavorite(at: index)
            return [.focusPanel]
        case .toggleFavorite:
            return toggleFavoriteForActiveSurface()
        case .openPicker:
            activatePicker()
            return [.focusPathField]
        case .exitPicker:
            exitPicker()
            return [.focusPanel]
        case .refocusPathField:
            return [.focusPathField]
        case .showHelp:
            setHelpVisible(true)
            return [.focusPanel]
        default:
            return performAction(intent)
        }
    }

    private func performAction(_ intent: PanelIntent) -> [PanelEffect] {
        switch intent {
        case .openInFinder:
            guard hasActionTarget else {
                return []
            }
            return [
                .revealInFinder(actionTarget, isDirectory: actionTargetIsDirectory),
                .dismiss,
            ]
        case .openInTerminal:
            guard canActOnTarget else {
                return []
            }
            let target = TerminalTarget.directory(
                for: actionTarget,
                isDirectory: actionTargetIsDirectory
            )
            return [.openInTerminal(target), .dismiss]
        case .copyPath:
            guard canActOnTarget else {
                return []
            }
            return [.copyPath(actionTarget), .dismiss]
        case .dismissPanel:
            return [.dismiss]
        default:
            return []
        }
    }

    private func moveSelection(by offset: Int) {
        if picker.isActive {
            picker.moveSelection(by: offset)
            return
        }
        browser.engageKeyboard()
        if zone == .favorites {
            moveFavoriteSelection(by: offset)
        } else {
            browser.moveSelection(by: offset)
        }
    }

    private func completePickedPath() {
        guard let completed = picker.completionText() else {
            return
        }
        picker.updateText(completed)
    }

    private func toggleFavoriteForActiveSurface() -> [PanelEffect] {
        guard picker.isActive else {
            toggleFavoriteForCurrentZone()
            return []
        }
        guard let entry = picker.selectedEntry else {
            return []
        }
        if favorites.contains(url: entry.url) {
            removeFavoriteByURL(entry.url)
        } else {
            addFavorite(entry)
        }
        return []
    }
}
