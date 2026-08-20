import Foundation

public struct Favorite: Equatable, Sendable, Codable, Identifiable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case directory
        case file
        case script
    }

    public let id: UUID
    public var url: URL
    public var kind: Kind
    public var alias: String?

    public var displayName: String {
        guard let alias, !alias.isEmpty else {
            return PathDisplay.name(for: url)
        }
        return alias
    }

    public init(id: UUID = UUID(), url: URL, kind: Kind = .directory, alias: String? = nil) {
        self.id = id
        self.url = url
        self.kind = kind
        self.alias = alias
    }
}

public struct FavoriteList: Equatable, Sendable {
    public private(set) var items: [Favorite]
    public private(set) var selectedID: Favorite.ID?

    public init(items: [Favorite] = [], selectedID: Favorite.ID? = nil) {
        self.items = items
        self.selectedID = items.contains(where: { $0.id == selectedID }) ? selectedID : nil
    }
}

public extension FavoriteList {
    static let shortcutCapacity = 10

    var isEmpty: Bool {
        items.isEmpty
    }

    var selected: Favorite? {
        guard let selectedID else {
            return nil
        }
        return items.first { $0.id == selectedID }
    }

    func contains(url: URL) -> Bool {
        index(of: url) != nil
    }

    func index(of url: URL) -> Int? {
        let target = url.standardizedFileURL.path
        return items.firstIndex { $0.url.standardizedFileURL.path == target }
    }

    static func shortcutChord(at index: Int) -> KeyChord? {
        guard index >= 0, index < shortcutCapacity else {
            return nil
        }
        let digit = index == shortcutCapacity - 1 ? 0 : index + 1
        guard digit < 10, let character = String(digit).first else {
            return nil
        }
        return KeyChord(.character(character), .command)
    }

    static func shortcut(at index: Int) -> String? {
        shortcutChord(at: index).map(KeyChordFormatter.spaced)
    }

    func shortcut(for id: Favorite.ID) -> String? {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Self.shortcut(at: index)
    }

    @discardableResult
    mutating func add(_ favorite: Favorite) -> Bool {
        guard !contains(url: favorite.url) else {
            return false
        }
        items.append(favorite)
        return true
    }

    @discardableResult
    mutating func remove(url: URL) -> Bool {
        guard let index = index(of: url) else {
            return false
        }
        removeItem(at: index)
        return true
    }

    @discardableResult
    mutating func remove(id: Favorite.ID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return false
        }
        removeItem(at: index)
        return true
    }

    mutating func move(from source: Int, to destination: Int) {
        guard items.indices.contains(source) else {
            return
        }
        let clamped = min(max(destination, 0), items.count - 1)
        guard clamped != source else {
            return
        }
        let moved = items.remove(at: source)
        items.insert(moved, at: clamped)
    }

    mutating func select(_ id: Favorite.ID?) {
        guard let id, items.contains(where: { $0.id == id }) else {
            selectedID = nil
            return
        }
        selectedID = id
    }

    mutating func setAlias(_ alias: String?, for id: Favorite.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].alias = alias
    }

    private mutating func removeItem(at index: Int) {
        let removed = items.remove(at: index)
        if removed.id == selectedID {
            selectedID = nil
        }
    }
}

public enum FavoriteStore {
    private struct Payload: Codable {
        var version: Int
        var items: [Favorite]
        var selectedID: UUID?
    }

    public static let currentVersion = 1

    public static func encode(_ list: FavoriteList) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Payload(
            version: currentVersion,
            items: list.items,
            selectedID: list.selectedID
        ))
    }

    public static func decode(_ data: Data) throws -> FavoriteList {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return FavoriteList(items: payload.items, selectedID: payload.selectedID)
    }
}

public enum PanelEntry {
    public static func startingDirectory(
        favorites: FavoriteList,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        guard let selected = favorites.selected else {
            return home
        }
        return selected.kind == .directory
            ? selected.url
            : selected.url.deletingLastPathComponent()
    }
}
