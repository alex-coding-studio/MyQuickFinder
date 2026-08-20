import Foundation

@MainActor
public final class DirectoryLoader {
    public typealias Progress = @Sendable (Int, Int) -> Void
    public typealias Outcome = Result<[DirectoryEntry], any Error>

    public private(set) var pending: Task<Void, Never>?

    private let reader: any DirectoryReading
    private let home: URL
    private let probe: @Sendable (URL) -> Bool
    private var generation = 0

    public init(
        reader: any DirectoryReading,
        home: URL,
        probe: @escaping @Sendable (URL) -> Bool = ProtectedDirectory.isReadable
    ) {
        self.reader = reader
        self.home = home
        self.probe = probe
    }

    private nonisolated static func entries(
        in url: URL,
        reader: any DirectoryReading,
        home: URL,
        probe: @escaping @Sendable (URL) -> Bool,
        onProgress: @escaping Progress
    ) async throws -> [DirectoryEntry] {
        try await Task.detached(priority: .userInitiated) {
            let listed = try reader.read(url, home: home, onProgress: onProgress)
            return DirectoryListing.resolvingBlocked(listed, probe: probe)
        }.value
    }

    public func cancel() {
        pending?.cancel()
        pending = nil
        generation += 1
    }

    public func load(
        _ candidates: [URL],
        onProgress: @escaping Progress = { _, _ in },
        then receive: @escaping @MainActor (URL, Outcome) -> Void
    ) {
        pending?.cancel()
        generation += 1
        let token = generation
        let reader = reader
        let home = home
        let probe = probe
        pending = Task { [weak self] in
            var settled: (url: URL, outcome: Outcome)?
            for candidate in candidates {
                do {
                    let entries = try await Self.entries(
                        in: candidate,
                        reader: reader,
                        home: home,
                        probe: probe,
                        onProgress: onProgress
                    )
                    settled = (candidate, .success(entries))
                    break
                } catch {
                    settled = (candidate, .failure(error))
                }
            }
            guard
                !Task.isCancelled,
                let settled,
                let self,
                token == generation
            else {
                return
            }
            receive(settled.url, settled.outcome)
        }
    }
}
