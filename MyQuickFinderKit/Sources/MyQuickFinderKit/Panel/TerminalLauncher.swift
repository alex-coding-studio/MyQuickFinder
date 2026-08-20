import Foundation

public protocol TerminalLauncher: Sendable {
    func open(_ directory: URL) throws
}

public enum TerminalTarget {
    public static func directory(for url: URL, isDirectory: Bool) -> URL {
        isDirectory ? url.standardizedFileURL : url.standardizedFileURL.deletingLastPathComponent()
    }
}
