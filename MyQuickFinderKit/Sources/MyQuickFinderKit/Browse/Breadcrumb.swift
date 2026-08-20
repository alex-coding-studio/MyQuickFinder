import Foundation

public struct BreadcrumbSegment: Equatable, Sendable, Identifiable {
    public let name: String
    public let url: URL
    public let depth: Int

    public var id: URL {
        url
    }

    public init(name: String, url: URL, depth: Int) {
        self.name = name
        self.url = url
        self.depth = depth
    }
}

public struct Breadcrumb: Equatable, Sendable {
    public let root: BreadcrumbSegment
    public let collapsed: [BreadcrumbSegment]
    public let trailing: [BreadcrumbSegment]

    public init(
        root: BreadcrumbSegment,
        collapsed: [BreadcrumbSegment],
        trailing: [BreadcrumbSegment]
    ) {
        self.root = root
        self.collapsed = collapsed
        self.trailing = trailing
    }
}

public extension Breadcrumb {
    static let trailingKeep = 2

    static func make(
        for url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        keeping keep: Int = trailingKeep
    ) -> Breadcrumb {
        let target = url.standardizedFileURL
        let homeTarget = home.standardizedFileURL
        let insideHome = target.path == homeTarget.path || target.path.hasPrefix(
            homeTarget.path + "/"
        )
        let rootURL = insideHome ? homeTarget : URL(fileURLWithPath: "/")
        let root = BreadcrumbSegment(name: insideHome ? "~" : "/", url: rootURL, depth: 0)

        var segments = [BreadcrumbSegment]()
        var walked = rootURL
        for (offset, component) in relativeComponents(of: target, under: rootURL).enumerated() {
            walked = walked.appendingPathComponent(component)
            segments.append(BreadcrumbSegment(name: component, url: walked, depth: offset + 1))
        }

        guard segments.count > keep, keep >= 0 else {
            return Breadcrumb(root: root, collapsed: [], trailing: segments)
        }
        let split = segments.count - keep
        return Breadcrumb(
            root: root,
            collapsed: Array(segments[..<split]),
            trailing: Array(segments[split...])
        )
    }

    var current: BreadcrumbSegment {
        trailing.last ?? root
    }

    var ancestors: [BreadcrumbSegment] {
        guard !trailing.isEmpty else {
            return []
        }
        return [root] + collapsed + Array(trailing.dropLast())
    }

    var isCollapsed: Bool {
        !collapsed.isEmpty
    }

    var parent: BreadcrumbSegment? {
        ancestors.last
    }

    static func parentDirectory(of url: URL) -> URL? {
        let target = url.standardizedFileURL
        guard target.path != "/" else {
            return nil
        }
        return target.deletingLastPathComponent().standardizedFileURL
    }

    private static func relativeComponents(of target: URL, under root: URL) -> [String] {
        guard target.path != root.path else {
            return []
        }
        let dropped = root.path == "/" ? 1 : root.path.count + 1
        return target.path.dropFirst(dropped).split(separator: "/").map(String.init)
    }
}
