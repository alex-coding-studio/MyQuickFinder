import Foundation

public struct DisplayName: Equatable, Sendable {
    public enum Treatment: Equatable, Sendable {
        case plain
        case middleTruncated
        case hash
    }

    public let text: String
    public let treatment: Treatment

    public init(text: String, treatment: Treatment) {
        self.text = text
        self.treatment = treatment
    }
}

public extension DisplayName {
    static let plainLimit = 24
    static let trailingKeep = 14
    static let hashPrefixLength = 10
    static let hashMinimumLength = 32
    static let ellipsis = "…"

    static func render(_ raw: String, limit: Int = plainLimit) -> DisplayName {
        if isHash(raw) {
            return DisplayName(
                text: String(raw.prefix(hashPrefixLength)) + ellipsis,
                treatment: .hash
            )
        }
        guard raw.count > limit else {
            return DisplayName(text: raw, treatment: .plain)
        }
        let tail = min(trailingKeep, max(limit - 2, 1))
        let head = max(limit - tail - 1, 1)
        return DisplayName(
            text: String(raw.prefix(head)) + ellipsis + String(raw.suffix(tail)),
            treatment: .middleTruncated
        )
    }

    static func isHash(_ raw: String) -> Bool {
        raw.count >= hashMinimumLength && raw.allSatisfy(lowercaseHexDigits.contains)
    }

    static func needsTimeColumn(names: [String], limit: Int = plainLimit) -> Bool {
        if names.contains(where: isHash) {
            return true
        }
        var rendered = Set<String>()
        for name in names where !rendered.insert(render(name, limit: limit).text).inserted {
            return true
        }
        return false
    }
}

private let lowercaseHexDigits: Set<Character> = Set("0123456789abcdef")
