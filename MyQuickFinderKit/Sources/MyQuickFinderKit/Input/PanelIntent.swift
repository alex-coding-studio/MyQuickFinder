import Foundation

public enum PanelSurface: Equatable, Sendable {
    case browse
    case picker
}

public struct PanelInputContext: Equatable, Sendable {
    public let surface: PanelSurface
    public let showsHelp: Bool
    public let showsAncestors: Bool
    public let isTextFieldFocused: Bool
    public let hasTextSelection: Bool
    public let isCaretAtEnd: Bool
    public let isTextEmpty: Bool
    public let isTextPristine: Bool
    public let isComposingText: Bool

    init(
        surface: PanelSurface,
        showsHelp: Bool = false,
        showsAncestors: Bool = false,
        isTextFieldFocused: Bool = false,
        hasTextSelection: Bool = false,
        isCaretAtEnd: Bool = true,
        isTextEmpty: Bool = false,
        isTextPristine: Bool = false,
        isComposingText: Bool = false
    ) {
        self.surface = surface
        self.showsHelp = showsHelp
        self.showsAncestors = showsAncestors
        self.isTextFieldFocused = isTextFieldFocused
        self.hasTextSelection = hasTextSelection
        self.isCaretAtEnd = isCaretAtEnd
        self.isTextEmpty = isTextEmpty
        self.isTextPristine = isTextPristine
        self.isComposingText = isComposingText
    }
}

public enum PanelIntent: Equatable, Sendable {
    case moveSelection(Int)
    case enterSelection
    case goToParent
    case switchZone
    case activateFavorite(index: Int)
    case toggleFavorite
    case toggleHidden
    case openPicker
    case exitPicker
    case clearPickerText
    case completePath
    case collapseSelectionToEnd
    case refocusPathField
    case showHelp
    case hideHelp
    case openAncestors
    case moveAncestorSelection(Int)
    case confirmAncestor
    case closeAncestors
    case openInFinder
    case openInTerminal
    case copyPath
    case dismissPanel

    public var allowsRepeat: Bool {
        switch self {
        case .moveSelection, .moveAncestorSelection, .enterSelection, .goToParent:
            true
        default:
            false
        }
    }
}

public enum PanelKeyResolution: Equatable, Sendable {
    case intent(PanelIntent)
    case swallow
    case pass
}
