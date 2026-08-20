import Foundation

public struct KeyChord: Equatable, Hashable, Sendable, Codable {
    public enum Key: Equatable, Hashable, Sendable {
        case character(Character)
        case up
        case down
        case left
        case right
        case tab
        case `return`
        case escape
    }

    public struct Modifiers: OptionSet, Hashable, Sendable, Codable {
        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public let key: Key
    public let modifiers: Modifiers

    public init(_ key: Key, _ modifiers: Modifiers = []) {
        self.key = Self.normalize(key)
        self.modifiers = modifiers
    }

    private static func normalize(_ key: Key) -> Key {
        guard case let .character(character) = key else {
            return key
        }
        let lowered = String(character).lowercased()
        return .character(lowered.first ?? character)
    }
}

public extension KeyChord.Modifiers {
    struct Layout: Equatable, Sendable {
        public let command: Int
        public let option: Int
        public let shift: Int
        public let control: Int

        public init(command: Int, option: Int, shift: Int, control: Int) {
            self.command = command
            self.option = option
            self.shift = shift
            self.control = control
        }
    }

    static func decoding(_ raw: Int, using layout: Layout) -> KeyChord.Modifiers {
        var decoded = KeyChord.Modifiers()
        if raw & layout.command != 0 {
            decoded.insert(.command)
        }
        if raw & layout.option != 0 {
            decoded.insert(.option)
        }
        if raw & layout.shift != 0 {
            decoded.insert(.shift)
        }
        if raw & layout.control != 0 {
            decoded.insert(.control)
        }
        return decoded
    }
}

public struct PathFieldFacts: Equatable, Sendable {
    public let selectionLength: Int
    public let caretLocation: Int
    public let isComposing: Bool

    public init(selectionLength: Int, caretLocation: Int, isComposing: Bool) {
        self.selectionLength = selectionLength
        self.caretLocation = caretLocation
        self.isComposing = isComposing
    }
}
