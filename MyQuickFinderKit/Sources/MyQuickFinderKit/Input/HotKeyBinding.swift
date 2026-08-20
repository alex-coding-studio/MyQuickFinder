import Foundation

public struct HotKeyBinding: Equatable, Sendable, Codable {
    public let keyCode: UInt32
    public let carbonModifiers: UInt32

    public var hasModifier: Bool {
        carbonModifiers != 0
    }

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }
}

public protocol HotKeyStoring: Sendable {
    func load() -> HotKeyBinding
    func save(_ binding: HotKeyBinding) throws
}

public struct HotKeyFileStorage: HotKeyStoring {
    public static let fileName = "hotkey.json"

    private let url: URL
    private let fallback: HotKeyBinding

    public init(url: URL, fallback: HotKeyBinding) {
        self.url = url
        self.fallback = fallback
    }

    public init(directoryName: String, fallback: HotKeyBinding) {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(
                path: "Library/Application Support"
            )
        self.init(
            url: base.appending(path: directoryName).appending(path: Self.fileName),
            fallback: fallback
        )
    }

    public func load() -> HotKeyBinding {
        guard
            let data = try? Data(contentsOf: url),
            let binding = try? JSONDecoder().decode(HotKeyBinding.self, from: data)
        else {
            return fallback
        }
        return binding
    }

    public func save(_ binding: HotKeyBinding) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(binding).write(to: url, options: .atomic)
    }
}

public final class InMemoryHotKeyStorage: HotKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: HotKeyBinding

    public init(_ initial: HotKeyBinding) {
        stored = initial
    }

    public func load() -> HotKeyBinding {
        lock.withLock { stored }
    }

    public func save(_ binding: HotKeyBinding) throws {
        lock.withLock { stored = binding }
    }
}
