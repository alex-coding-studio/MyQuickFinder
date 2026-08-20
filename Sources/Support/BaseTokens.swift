import SwiftUI

enum BaseTokens {
    struct ElevationStyle: Equatable, Sendable {
        let opacity: Double
        let radius: CGFloat
        let offset: CGSize
    }

    enum Border {
        static let hairline: CGFloat = 0.5
    }

    enum Height {
        static let snug: CGFloat = 28
    }

    enum IconSize {
        static let selection: CGFloat = 20
    }

    enum Inset {
        static let micro: CGFloat = 4
        static let compact: CGFloat = 8
    }

    enum Opacity {
        static let faint: CGFloat = 0.16
        static let medium: CGFloat = 0.32
        static let heavy: CGFloat = 0.85
    }

    enum Spacing {
        static let micro: CGFloat = 4
        static let inline: CGFloat = 8
        static let section: CGFloat = 24
    }
}

extension View {
    func elevationShadow(
        _ elevation: BaseTokens.ElevationStyle,
        color: Color = .black
    ) -> some View {
        shadow(
            color: color.opacity(elevation.opacity),
            radius: elevation.radius,
            x: elevation.offset.width,
            y: elevation.offset.height
        )
    }
}
