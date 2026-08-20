import Foundation

public enum PathDisplay {
    public static func name(for url: URL) -> String {
        let component = url.standardizedFileURL.lastPathComponent
        return component.isEmpty ? "/" : component
    }

    public static func abbreviatingHome(
        _ url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        if path == homePath {
            return "~"
        }
        guard path.hasPrefix(homePath + "/") else {
            return path
        }
        return "~" + String(path.dropFirst(homePath.count))
    }
}
