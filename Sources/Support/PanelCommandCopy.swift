import Foundation
import MyQuickFinderKit

enum PanelCommandCopy {
    static let helpGroups: [(title: String, commands: [PanelCommand])] = [
        (
            String(localized: "command.group.navigation"),
            [.moveSelectionUp, .enterSelection, .goToParent, .openAncestors, .switchZone]
        ),
        (String(localized: "command.group.pathBar"), [.openPicker, .completePath]),
        (String(localized: "command.group.favorites"), [.activateFavorite, .toggleFavorite]),
        (String(localized: "command.group.actions"), [.openInFinder, .openInTerminal, .copyPath]),
        (String(localized: "command.group.other"), [.toggleHidden, .showHelp, .dismissPanel]),
    ]

    static let helpOrder: [PanelCommand] = [
        .moveSelectionUp,
        .enterSelection,
        .goToParent,
        .openAncestors,
        .switchZone,
        .openPicker,
        .completePath,
        .activateFavorite,
        .toggleFavorite,
        .toggleHidden,
        .openInFinder,
        .openInTerminal,
        .copyPath,
        .showHelp,
        .dismissPanel,
    ]

    private static let shortTitles: [PanelCommand: String] = [
        .openInFinder: String(localized: "command.short.openInFinder"),
        .openInTerminal: String(localized: "command.short.openInTerminal"),
        .copyPath: String(localized: "command.short.copyPath"),
    ]

    private static let titles: [PanelCommand: String] = [
        .openInFinder: String(localized: "command.openInFinder"),
        .openInTerminal: String(localized: "command.openInTerminal"),
        .copyPath: String(localized: "command.copyPath"),
        .toggleFavorite: String(localized: "command.toggleFavorite"),
        .showHelp: String(localized: "command.showHelp"),
        .openPicker: String(localized: "command.openPicker"),
        .toggleHidden: String(localized: "command.toggleHidden"),
        .openAncestors: String(localized: "command.openAncestors"),
        .activateFavorite: String(localized: "command.activateFavorite"),
        .moveSelectionUp: String(localized: "command.moveSelection"),
        .moveSelectionDown: String(localized: "command.moveSelection"),
        .enterSelection: String(localized: "command.enterSelection"),
        .goToParent: String(localized: "command.goToParent"),
        .switchZone: String(localized: "command.switchZone"),
        .completePath: String(localized: "command.completePath"),
        .dismissPanel: String(localized: "command.dismissPanel"),
    ]

    static var customizable: [PanelCommand] {
        helpOrder.filter(\.isCustomizable)
    }

    static func title(_ command: PanelCommand) -> String {
        titles[command] ?? command.rawValue
    }

    static func keyCap(_ command: PanelCommand, in bindings: KeyBindings) -> String {
        cap(command, in: bindings, render: KeyChordFormatter.display, gap: " ")
    }

    static func settingsCap(_ command: PanelCommand, in bindings: KeyBindings) -> String {
        cap(command, in: bindings, render: KeyChordFormatter.spaced, gap: "   ")
    }

    static func shortCap(_ command: PanelCommand, in bindings: KeyBindings) -> String {
        guard let chord = bindings.chord(for: command) else {
            return ""
        }
        return KeyChordFormatter.spaced(chord)
    }

    static func shortTitle(_ command: PanelCommand) -> String {
        shortTitles[command] ?? title(command)
    }

    private static func cap(
        _ command: PanelCommand,
        in bindings: KeyBindings,
        render: ([KeyChord]) -> String,
        gap: String
    ) -> String {
        switch command {
        case .activateFavorite:
            favoriteCap(render: render, gap: gap)
        case .moveSelectionUp, .moveSelectionDown:
            [PanelCommand.moveSelectionUp, .moveSelectionDown]
                .map { render(bindings.chords(for: $0)) }
                .filter { !$0.isEmpty }
                .joined(separator: gap)
        default:
            render(bindings.chords(for: command))
        }
    }

    private static func favoriteCap(render: ([KeyChord]) -> String, gap: String) -> String {
        let capacity = FavoriteList.shortcutCapacity
        guard
            let first = FavoriteList.shortcutChord(at: 0),
            let last = FavoriteList.shortcutChord(at: capacity - 1)
        else {
            return ""
        }
        guard
            capacity > 2,
            let through = FavoriteList.shortcutChord(at: capacity - 2)
        else {
            return render([first]) + gap + render([last])
        }
        return render([first])
            + "–"
            + KeyChordFormatter.symbol(through.key)
            + gap
            + render([last])
    }
}
