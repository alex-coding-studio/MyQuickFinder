import Foundation

public struct DirectoryEntry: Equatable, Sendable, Identifiable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isBlocked: Bool
    public let modifiedAt: Date?

    public var id: URL {
        url
    }

    public var isHidden: Bool {
        name.hasPrefix(".")
    }

    public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        isBlocked: Bool = false,
        modifiedAt: Date? = nil
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isBlocked = isBlocked
        self.modifiedAt = modifiedAt
    }
}

public enum DirectoryState: Equatable, Sendable {
    case loading(read: Int, total: Int?)
    case populated([DirectoryEntry])
    case empty
    case denied
    case missing
    case failed(String)
}

public struct ArrangedDirectory: Equatable, Sendable {
    public let entries: [DirectoryEntry]
    public let hiddenCount: Int
    public let showsTimeColumn: Bool

    public init(entries: [DirectoryEntry], hiddenCount: Int, showsTimeColumn: Bool) {
        self.entries = entries
        self.hiddenCount = hiddenCount
        self.showsTimeColumn = showsTimeColumn
    }
}

public extension DirectoryEntry {
    func markingBlocked(_ blocked: Bool) -> DirectoryEntry {
        DirectoryEntry(
            url: url,
            name: name,
            isDirectory: isDirectory,
            isBlocked: blocked,
            modifiedAt: modifiedAt
        )
    }
}

public enum DirectoryListing {
    public static func resolvingBlocked(
        _ entries: [DirectoryEntry],
        probe: @Sendable (URL) -> Bool
    ) -> [DirectoryEntry] {
        entries.map { entry in
            guard entry.isBlocked else {
                return entry
            }
            return entry.markingBlocked(!probe(entry.url))
        }
    }

    public static func arrange(
        _ entries: [DirectoryEntry],
        showingHidden: Bool
    ) -> ArrangedDirectory {
        let hidden = entries.filter(\.isHidden)
        let kept = showingHidden ? entries : entries.filter { !$0.isHidden }
        let sorted = kept.sorted(by: precedes)
        return ArrangedDirectory(
            entries: sorted,
            hiddenCount: showingHidden ? 0 : hidden.count,
            showsTimeColumn: DisplayName.needsTimeColumn(names: sorted.map(\.name))
        )
    }

    public static func state(for arranged: ArrangedDirectory) -> DirectoryState {
        arranged.entries.isEmpty ? .empty : .populated(arranged.entries)
    }

    public static func state(for error: Error) -> DirectoryState {
        let failure = error as NSError
        if failure.domain == NSCocoaErrorDomain, failure.code == NSFileReadNoPermissionError {
            return .denied
        }
        if failure.domain == NSPOSIXErrorDomain, failure.code == Int(EACCES) || failure.code == Int(
            EPERM
        ) {
            return .denied
        }
        if let underlying = failure.userInfo[
            NSUnderlyingErrorKey
        ] as? NSError, underlying !== failure {
            return state(for: underlying)
        }
        if failure.domain == NSCocoaErrorDomain, failure.code == NSFileReadNoSuchFileError {
            return .missing
        }
        if failure.domain == NSPOSIXErrorDomain, failure.code == Int(ENOENT) {
            return .missing
        }
        return .failed(failure.localizedDescription)
    }

    private static func precedes(_ lhs: DirectoryEntry, _ rhs: DirectoryEntry) -> Bool {
        guard lhs.isDirectory == rhs.isDirectory else {
            return lhs.isDirectory
        }
        let ordering = lhs.name.localizedStandardCompare(rhs.name)
        return ordering == .orderedAscending
    }
}

public enum ProtectedDirectory {
    public static let homeChildren = ["Desktop", "Documents", "Downloads"]

    public static func isReadable(_ url: URL) -> Bool {
        let descriptor = open(url.standardizedFileURL.path, O_RDONLY | O_DIRECTORY)
        guard descriptor >= 0 else {
            return false
        }
        close(descriptor)
        return true
    }

    public static func isProtected(
        _ url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let target = url.standardizedFileURL
        let parent = target.deletingLastPathComponent().standardizedFileURL
        guard parent.path == home.standardizedFileURL.path else {
            return false
        }
        return homeChildren.contains(target.lastPathComponent)
    }
}
