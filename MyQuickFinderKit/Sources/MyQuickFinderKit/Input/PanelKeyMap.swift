import Foundation

public enum PanelKeyMap {
    public static func resolve(
        _ chord: KeyChord,
        in context: PanelInputContext,
        bindings: KeyBindings = .default
    ) -> PanelKeyResolution {
        guard !context.isComposingText else {
            return .pass
        }
        if context.showsAncestors {
            return ancestorMenu(chord)
        }
        if chord.modifiers.contains(.command) {
            return commandChord(chord, in: context, bindings)
        }
        switch context.surface {
        case .picker:
            return pickerChord(chord, in: context, bindings)
        case .browse:
            return browseChord(chord, in: context, bindings)
        }
    }

    public static func favoriteIndex(for character: Character) -> Int? {
        guard let digit = character.wholeNumberValue, (0 ... 9).contains(digit) else {
            return nil
        }
        return digit == 0 ? FavoriteList.shortcutCapacity - 1 : digit - 1
    }

    private static func ancestorMenu(_ chord: KeyChord) -> PanelKeyResolution {
        switch chord.key {
        case .up:
            .intent(.moveAncestorSelection(-1))
        case .down:
            .intent(.moveAncestorSelection(1))
        case .return:
            .intent(.confirmAncestor)
        case .escape:
            .intent(.closeAncestors)
        default:
            .swallow
        }
    }

    private static func commandChord(
        _ chord: KeyChord,
        in context: PanelInputContext,
        _ bindings: KeyBindings
    ) -> PanelKeyResolution {
        if let shared = sharedCommand(chord, bindings) {
            return .intent(shared)
        }
        guard context.surface == .browse else {
            return .pass
        }
        return browseCommand(chord, bindings)
    }

    private static func sharedCommand(
        _ chord: KeyChord,
        _ bindings: KeyBindings
    ) -> PanelIntent? {
        if chord.modifiers == .command, case let .character(character) = chord.key,
           let index = favoriteIndex(for: character) {
            return .activateFavorite(index: index)
        }
        if bindings.matches(chord, .toggleFavorite) {
            return .toggleFavorite
        }
        if bindings.matches(chord, .showHelp) {
            return .showHelp
        }
        if bindings.matches(chord, .copyPath) {
            return .copyPath
        }
        if bindings.matches(chord, .openInTerminal) {
            return .openInTerminal
        }
        return nil
    }

    private static func browseCommand(
        _ chord: KeyChord,
        _ bindings: KeyBindings
    ) -> PanelKeyResolution {
        if bindings.matches(chord, .openAncestors) {
            return .intent(.openAncestors)
        }
        if bindings.matches(chord, .toggleHidden) {
            return .intent(.toggleHidden)
        }
        guard chord.modifiers == .command else {
            return .pass
        }
        switch chord.key {
        case .up:
            return .intent(.goToParent)
        case .down:
            return .intent(.enterSelection)
        default:
            return .pass
        }
    }

    private static func pickerChord(
        _ chord: KeyChord,
        in context: PanelInputContext,
        _ bindings: KeyBindings
    ) -> PanelKeyResolution {
        if let early = unfocusedPrelude(chord, in: context, bindings) {
            return early
        }
        switch chord.key {
        case .up:
            return .intent(.moveSelection(-1))
        case .down:
            return .intent(.moveSelection(1))
        case .tab:
            return .intent(.completePath)
        case .return:
            return .intent(.openInFinder)
        case .escape:
            return .intent(context.isTextEmpty ? .exitPicker : .clearPickerText)
        case .right:
            return rightArrowInField(context)
        default:
            return .pass
        }
    }

    private static func rightArrowInField(_ context: PanelInputContext) -> PanelKeyResolution {
        if context.hasTextSelection || context.isTextPristine {
            return .intent(.collapseSelectionToEnd)
        }
        guard context.isCaretAtEnd else {
            return .pass
        }
        return .intent(.completePath)
    }

    private static func unfocusedPrelude(
        _ chord: KeyChord,
        in context: PanelInputContext,
        _ bindings: KeyBindings
    ) -> PanelKeyResolution? {
        guard !context.isTextFieldFocused else {
            return nil
        }
        if context.showsHelp {
            return .intent(.hideHelp)
        }
        if bindings.matches(chord, .openPicker) {
            return .intent(.refocusPathField)
        }
        return nil
    }

    private static func browseChord(
        _ chord: KeyChord,
        in context: PanelInputContext,
        _ bindings: KeyBindings
    ) -> PanelKeyResolution {
        if bindings.matches(chord, .openPicker) {
            return .intent(.openPicker)
        }
        if context.showsHelp {
            return .intent(.hideHelp)
        }
        switch chord.key {
        case .tab:
            return .intent(.switchZone)
        case .up:
            return .intent(.moveSelection(-1))
        case .down:
            return .intent(.moveSelection(1))
        case .right:
            return .intent(.enterSelection)
        case .left:
            return .intent(.goToParent)
        case .return:
            return .intent(.openInFinder)
        case .escape:
            return .intent(.dismissPanel)
        default:
            return .pass
        }
    }
}
