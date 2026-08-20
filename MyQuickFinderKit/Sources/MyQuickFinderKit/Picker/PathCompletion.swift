import Foundation

public struct PathInput: Equatable, Sendable {
    public let directory: URL
    public let fragment: String
    public let prefix: String

    public init(directory: URL, fragment: String, prefix: String) {
        self.directory = directory
        self.fragment = fragment
        self.prefix = prefix
    }
}

public enum PathCompletion {
    public static let homeToken = "~"
    public static let separator = "/"

    public static func parse(_ raw: String, home: URL, base: URL) -> PathInput {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            return PathInput(directory: base, fragment: "", prefix: "")
        }

        let cut = text.lastIndex(of: Character(separator))
        guard let cut else {
            if text == homeToken {
                return PathInput(directory: home, fragment: "", prefix: homeToken + separator)
            }
            return PathInput(directory: base, fragment: text, prefix: "")
        }

        let head = String(text[text.startIndex ... cut])
        let fragment = String(text[text.index(after: cut)...])
        return PathInput(
            directory: resolve(head, home: home, base: base),
            fragment: fragment,
            prefix: head
        )
    }

    public static func wholePath(_ raw: String, home: URL, base: URL) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, text != homeToken else {
            return nil
        }
        let last = text.hasSuffix(separator)
            ? String(text.dropLast())
            : text
        let tail = last.components(separatedBy: separator).last ?? ""
        guard tail != ".", tail != ".." else {
            return nil
        }
        return resolve(text, home: home, base: base)
    }

    public static func filter(_ entries: [DirectoryEntry], fragment: String) -> [DirectoryEntry] {
        guard fragment.isEmpty == false else {
            return entries
        }
        let needle = fragment.lowercased()
        return entries
            .compactMap { entry -> (entry: DirectoryEntry, tier: Int)? in
                let name = entry.name.lowercased()
                if name.hasPrefix(needle) {
                    return (entry, 0)
                }
                if name.contains(needle) {
                    return (entry, 1)
                }
                return nil
            }
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.tier != rhs.element.tier
                    ? lhs.element.tier < rhs.element.tier
                    : lhs.offset < rhs.offset
            }
            .map(\.element.entry)
    }

    public static func commonPrefix(of entries: [DirectoryEntry]) -> String? {
        guard let first = entries.first?.name, entries.count > 1 else {
            return nil
        }
        var prefix = first
        for entry in entries.dropFirst() {
            prefix = String(prefix.commonPrefix(with: entry.name, options: .caseInsensitive))
            if prefix.isEmpty {
                return nil
            }
        }
        return prefix
    }

    public static func completeToCommonPrefix(
        _ raw: String,
        entries: [DirectoryEntry],
        home: URL,
        base: URL
    ) -> String? {
        let input = parse(raw, home: home, base: base)
        guard let shared = commonPrefix(of: entries), shared.count > input.fragment.count else {
            return nil
        }
        let head = input.prefix.isEmpty ? defaultPrefix(for: base, home: home) : input.prefix
        return head + shared
    }

    public static func complete(
        _ raw: String,
        with entry: DirectoryEntry,
        home: URL,
        base: URL
    ) -> String {
        let input = parse(raw, home: home, base: base)
        let head = input.prefix.isEmpty ? defaultPrefix(for: base, home: home) : input.prefix
        return head + entry.name + (entry.isDirectory ? separator : "")
    }

    public static func defaultPrefix(for directory: URL, home: URL) -> String {
        let shown = PathDisplay.abbreviatingHome(directory, home: home)
        return shown.hasSuffix(separator) ? shown : shown + separator
    }

    private static func resolve(_ head: String, home: URL, base: URL) -> URL {
        var path = head
        if path.count > 1, path.hasSuffix(separator) {
            path.removeLast()
        }
        if path == homeToken {
            return home
        }
        if path.hasPrefix(homeToken + separator) {
            return home.appending(path: String(path.dropFirst(2))).standardizedFileURL
        }
        if path.hasPrefix(separator) {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return base.appending(path: path).standardizedFileURL
    }
}
