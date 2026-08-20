import Foundation

public protocol DirectoryReading: Sendable {
    func read(
        _ url: URL,
        home: URL,
        onProgress: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry]
}

public extension DirectoryReading {
    func read(_ url: URL, home: URL) throws -> [DirectoryEntry] {
        try read(url, home: home, onProgress: { _, _ in })
    }
}

public struct DirectoryReader: DirectoryReading {
    public static let progressStride = 128

    private let stride: Int

    public init(stride: Int = progressStride) {
        self.stride = max(stride, 1)
    }

    public func read(
        _ url: URL,
        home: URL,
        onProgress: @Sendable (Int, Int) -> Void
    ) throws -> [DirectoryEntry] {
        let manager = FileManager.default
        let directory = url.standardizedFileURL
        let names = try manager.contentsOfDirectory(atPath: directory.path)
        let total = names.count
        onProgress(0, total)

        var entries = [DirectoryEntry]()
        entries.reserveCapacity(total)
        for (offset, name) in names.enumerated() {
            let child = directory.appending(path: name)
            let values = try? child.resourceValues(forKeys: [
                .isDirectoryKey,
                .contentModificationDateKey,
            ])
            let isDirectory = values?.isDirectory ?? false
            entries.append(
                DirectoryEntry(
                    url: child,
                    name: name,
                    isDirectory: isDirectory,
                    isBlocked: isDirectory && ProtectedDirectory.isProtected(child, home: home),
                    modifiedAt: values?.contentModificationDate
                )
            )
            if (offset + 1) % stride == 0 {
                onProgress(offset + 1, total)
            }
        }
        onProgress(total, total)
        return entries
    }
}
