import Foundation

public enum PanelCommand: String, CaseIterable, Codable, Sendable {
    case openInFinder
    case openInTerminal
    case copyPath
    case toggleFavorite
    case showHelp
    case openPicker
    case toggleHidden
    case openAncestors
    case activateFavorite
    case moveSelectionUp
    case moveSelectionDown
    case enterSelection
    case goToParent
    case switchZone
    case completePath
    case dismissPanel

    public var isCustomizable: Bool {
        switch self {
        case .toggleFavorite, .toggleHidden, .openAncestors, .showHelp:
            true
        default:
            false
        }
    }
}

public struct KeyBindings: Equatable, Sendable {
    public static let `default` = KeyBindings(chords: [
        .openInFinder: [KeyChord(.return)],
        .openInTerminal: [KeyChord(.return, .command)],
        .copyPath: [KeyChord(.character("c"), .command)],
        .toggleFavorite: [KeyChord(.character("d"), .command)],
        .showHelp: [KeyChord(.character("/"), .command)],
        .openPicker: [KeyChord(.character("/"))],
        .toggleHidden: [KeyChord(.character("."), [.command, .shift])],
        .openAncestors: [KeyChord(.up, [.command, .option])],
        .moveSelectionUp: [KeyChord(.up)],
        .moveSelectionDown: [KeyChord(.down)],
        .enterSelection: [KeyChord(.right), KeyChord(.down, .command)],
        .goToParent: [KeyChord(.left), KeyChord(.up, .command)],
        .switchZone: [KeyChord(.tab)],
        .completePath: [KeyChord(.tab), KeyChord(.right)],
        .dismissPanel: [KeyChord(.escape)],
    ])

    private let chords: [PanelCommand: [KeyChord]]

    public init(chords: [PanelCommand: [KeyChord]]) {
        self.chords = chords
    }

    public func chords(for command: PanelCommand) -> [KeyChord] {
        chords[command] ?? []
    }

    public func chord(for command: PanelCommand) -> KeyChord? {
        chords(for: command).first
    }

    public func matches(_ chord: KeyChord, _ command: PanelCommand) -> Bool {
        chords(for: command).contains(chord)
    }

    public func rebinding(_ command: PanelCommand, to chord: KeyChord) -> KeyBindings {
        var updated = chords
        updated[command] = [chord]
        return KeyBindings(chords: updated)
    }

    public func conflict(for chord: KeyChord, ignoring command: PanelCommand) -> PanelCommand? {
        chords
            .filter { $0.key != command }
            .first { $0.value.contains(chord) }?
            .key
    }
}

public enum KeyChordFormatter {
    public static func display(_ chord: KeyChord) -> String {
        symbols(chord).joined()
    }

    public static func display(_ chords: [KeyChord]) -> String {
        chords.map(display).joined(separator: " / ")
    }

    public static func spaced(_ chord: KeyChord) -> String {
        symbols(chord).joined(separator: " ")
    }

    public static func spaced(_ chords: [KeyChord]) -> String {
        chords.map(spaced).joined(separator: "  /  ")
    }

    public static func symbol(_ key: KeyChord.Key) -> String {
        switch key {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        case .tab: "⇥"
        case .return: "↩"
        case .escape: "⎋"
        case let .character(character): String(character).uppercased()
        }
    }

    private static func symbols(_ chord: KeyChord) -> [String] {
        modifiers(chord.modifiers) + [symbol(chord.key)]
    }

    private static func modifiers(_ modifiers: KeyChord.Modifiers) -> [String] {
        var symbols = [String]()
        if modifiers.contains(.control) {
            symbols.append("⌃")
        }
        if modifiers.contains(.option) {
            symbols.append("⌥")
        }
        if modifiers.contains(.shift) {
            symbols.append("⇧")
        }
        if modifiers.contains(.command) {
            symbols.append("⌘")
        }
        return symbols
    }
}

extension KeyChord.Key: Codable {
    private static let tokens: [KeyChord.Key: String] = [
        .up: "up",
        .down: "down",
        .left: "left",
        .right: "right",
        .tab: "tab",
        .return: "return",
        .escape: "escape",
    ]

    private static let characterPrefix = "character:"

    public init(from decoder: any Decoder) throws {
        let token = try decoder.singleValueContainer().decode(String.self)
        if let named = Self.tokens.first(where: { $0.value == token })?.key {
            self = named
            return
        }
        guard
            token.hasPrefix(Self.characterPrefix),
            let character = token.dropFirst(Self.characterPrefix.count).first
        else {
            throw try DecodingError.dataCorruptedError(
                in: decoder.singleValueContainer(),
                debugDescription: "Unrecognized key token"
            )
        }
        self = .character(character)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let token = Self.tokens[self] {
            try container.encode(token)
            return
        }
        guard case let .character(character) = self else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(codingPath: [], debugDescription: "Unencodable key")
            )
        }
        try container.encode(Self.characterPrefix + String(character))
    }
}

public protocol KeyBindingStoring: Sendable {
    func load() -> [PanelCommand: KeyChord]
    func save(_ overrides: [PanelCommand: KeyChord]) throws
}

public struct KeyBindingFileStorage: KeyBindingStoring {
    public static let fileName = "keybindings.json"

    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public init(directoryName: String) {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(
                path: "Library/Application Support"
            )
        self.init(url: base.appending(path: directoryName).appending(path: Self.fileName))
    }

    public func load() -> [PanelCommand: KeyChord] {
        guard
            let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode([String: KeyChord].self, from: data)
        else {
            return [:]
        }
        return raw.reduce(into: [:]) { result, entry in
            guard let command = PanelCommand(rawValue: entry.key) else {
                return
            }
            result[command] = entry.value
        }
    }

    public func save(_ overrides: [PanelCommand: KeyChord]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let raw = Dictionary(
            uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) }
        )
        try JSONEncoder().encode(raw).write(to: url, options: .atomic)
    }
}

public final class InMemoryKeyBindingStorage: KeyBindingStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [PanelCommand: KeyChord]

    public init(_ initial: [PanelCommand: KeyChord] = [:]) {
        stored = initial
    }

    public func load() -> [PanelCommand: KeyChord] {
        lock.withLock { stored }
    }

    public func save(_ overrides: [PanelCommand: KeyChord]) throws {
        lock.withLock { stored = overrides }
    }
}

public extension KeyBindings {
    static func resolving(_ overrides: [PanelCommand: KeyChord]) -> KeyBindings {
        overrides
            .filter(\.key.isCustomizable)
            .reduce(KeyBindings.default) { bindings, entry in
                guard bindings.conflict(for: entry.value, ignoring: entry.key) == nil else {
                    return bindings
                }
                return bindings.rebinding(entry.key, to: entry.value)
            }
    }
}
