// swiftlint:disable magic_font_size magic_layout_constant magic_opacity

import AppKit
import SwiftUI

enum DesignTokens {
    enum Panel {
        static let width: CGFloat = 380
        static let listInsetHorizontal: CGFloat = 6
        static let listInsetTop = BaseTokens.Inset.micro
        static let listInsetBottom = BaseTokens.Inset.micro + 2
        static let listMaxHeight: CGFloat = 288
        static let statusHeight: CGFloat = 104
        static let cornerRadius: CGFloat = 12
        static let elevation = BaseTokens.ElevationStyle(
            opacity: 0.24,
            radius: 22,
            offset: CGSize(width: 0, height: 16)
        )
    }

    enum Surface {
        static let material = NSVisualEffectView.Material.hudWindow
        static let blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        static let blurRadius: CGFloat = 32
        static let saturation: CGFloat = 1.4
    }

    enum Row {
        static let listHeight: CGFloat = 24
        static let favoriteHeight: CGFloat = 24
        static let breadcrumbHeight = BaseTokens.Height.snug
        static let sectionHeaderHeight: CGFloat = 22
        static let zoneHeaderHeight: CGFloat = 24
        static let horizontalInset = BaseTokens.Inset.compact
        static let chromeInset: CGFloat = 10
        static let proseInset: CGFloat = 14
        static let contentSpacing: CGFloat = 7
        static let chromeSpacing = BaseTokens.Spacing.micro
        static let cornerRadius: CGFloat = 5
        static let minimumHitHeight: CGFloat = 24
    }

    enum Pill {
        static let height: CGFloat = 22
        static let cornerRadius: CGFloat = 11
        static let compactInset: CGFloat = 9
        static let inset = BaseTokens.Inset.compact + 2
        static let spacing = BaseTokens.Spacing.inline - 2
        static let capSpacing = BaseTokens.Spacing.inline + 3
        static let disabledOpacity = BaseTokens.Opacity.medium
    }

    enum Icon {
        static let list: CGFloat = 14
        static let status = BaseTokens.IconSize.selection
    }

    enum Settings {
        static let width: CGFloat = 520
        static let labelColumnWidth: CGFloat = 118
        static let inset = BaseTokens.Spacing.section
        static let rowSpacing: CGFloat = 12
        static let fieldWidth: CGFloat = 108
        static let fieldHeight: CGFloat = 17
        static let contentMinHeight: CGFloat = 200
    }

    enum Typography {
        static let listItem = Font.system(size: 13)
        static let fieldPointSize: CGFloat = 13
        static let compactFieldPointSize: CGFloat = 11
        static let breadcrumbCurrent = Font.system(size: 12, weight: .semibold)
        static let breadcrumbAncestor = Font.system(size: 12)
        static let sectionHeader = Font.system(size: 11)
        static let count = Font.system(size: 11)
        static let sectionHeaderTracking: CGFloat = 0.66
        static let keyCap = Font.system(size: 10, design: .monospaced)
        static let path = Font.system(size: 10, design: .monospaced)
    }

    enum Ink {
        static let primary = Color.primary
        static let secondary = Color.primary.opacity(0.62)
        static let tertiary = Color.primary.opacity(BaseTokens.Opacity.medium)
    }

    enum Separator {
        static let width = BaseTokens.Border.hairline
        static let color = Color.designDynamic(
            light: NSColor.black.withAlphaComponent(0.14),
            dark: NSColor.white.withAlphaComponent(0.18)
        )
    }

    enum Selection {
        static let active = Color.designDynamic(
            light: NSColor(designHex: 0x0A6CFF),
            dark: NSColor(designHex: 0x3A8BFF)
        )
        static let inactiveFill = Color.designDynamic(
            light: NSColor.black.withAlphaComponent(0.12),
            dark: NSColor.white.withAlphaComponent(0.28)
        )
    }

    enum Status {
        static let favorite = Color.designDynamic(
            light: NSColor(designHex: 0xC98A00),
            dark: NSColor(designHex: 0xF0C000)
        )
        static let denied = Color.designDynamic(
            light: NSColor(designHex: 0xE06A1F),
            dark: NSColor(designHex: 0xFF9142)
        )
    }

    enum Motion {
        static let dismiss: TimeInterval = 0.1
        static let selection: TimeInterval = 0.18
        static let levelChange: TimeInterval = 0.28
    }
}

private extension NSColor {
    convenience init(designHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    static func designDynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}
