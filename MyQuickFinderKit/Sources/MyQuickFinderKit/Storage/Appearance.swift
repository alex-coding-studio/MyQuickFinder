import Foundation

public enum Appearance: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}

public protocol AppearanceStoring: Sendable {
    func load() -> Appearance
    func save(_ appearance: Appearance) throws
}

public struct AppearanceFileStorage: AppearanceStoring {
    public static let fileName = "appearance.json"

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

    public func load() -> Appearance {
        guard
            let data = try? Data(contentsOf: url),
            let stored = try? JSONDecoder().decode(Appearance.self, from: data)
        else {
            return .system
        }
        return stored
    }

    public func save(_ appearance: Appearance) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(appearance).write(to: url, options: .atomic)
    }
}

public final class InMemoryAppearanceStorage: AppearanceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Appearance

    public init(_ initial: Appearance = .system) {
        stored = initial
    }

    public func load() -> Appearance {
        lock.withLock { stored }
    }

    public func save(_ appearance: Appearance) throws {
        lock.withLock { stored = appearance }
    }
}
