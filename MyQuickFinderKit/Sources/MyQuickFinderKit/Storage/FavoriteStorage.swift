import Foundation

public protocol FavoriteStoring: Sendable {
    func load() -> FavoriteList
    func save(_ list: FavoriteList) throws
}

public struct FavoriteFileStorage: FavoriteStoring {
    public static let fileName = "favorites.json"

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

    public func load() -> FavoriteList {
        guard let data = try? Data(contentsOf: url) else {
            return FavoriteList()
        }
        return (try? FavoriteStore.decode(data)) ?? FavoriteList()
    }

    public func save(_ list: FavoriteList) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FavoriteStore.encode(list).write(to: url, options: .atomic)
    }
}

public final class InMemoryFavoriteStorage: FavoriteStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: FavoriteList

    public init(_ initial: FavoriteList = FavoriteList()) {
        stored = initial
    }

    public func load() -> FavoriteList {
        lock.withLock { stored }
    }

    public func save(_ list: FavoriteList) throws {
        lock.withLock { stored = list }
    }
}
