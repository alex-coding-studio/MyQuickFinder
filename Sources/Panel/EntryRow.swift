import MyQuickFinderKit
import SwiftUI

struct EntryRow: View {
    private enum Metrics {
        static let hashFontSize: CGFloat = 11.5
        static let timeColumnWidth: CGFloat = 64
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    @State private var isHovered = false

    let entry: DirectoryEntry
    let showsTime: Bool
    let isSelected: Bool
    let isActive: Bool
    let isFavorited: Bool
    let favoriteShortcut: String?
    let canFavorite: Bool
    let onToggleFavorite: () -> Void

    private var rendered: DisplayName {
        DisplayName.render(entry.name)
    }

    private var foreground: Color {
        isSelected && isActive ? .white : DesignTokens.Ink.primary
    }

    private var background: Color {
        guard isSelected else {
            return .clear
        }
        return isActive ? DesignTokens.Selection.active : DesignTokens.Selection.inactiveFill
    }

    private var symbol: String {
        if entry.isBlocked {
            return "lock.fill"
        }
        return entry.isDirectory ? "folder" : "doc"
    }

    private var showsIdleStar: Bool {
        canFavorite && !isFavorited && (isSelected || isHovered)
    }

    private var iconOpacity: Double {
        isSelected && isActive ? 1 : 0.62
    }

    var body: some View {
        HStack(spacing: DesignTokens.Row.contentSpacing) {
            Image(systemName: symbol)
                .font(.system(size: DesignTokens.Icon.list))
                .foregroundStyle(
                    entry.isBlocked && !isSelected ? DesignTokens.Status.denied : foreground.opacity(
                        iconOpacity
                    )
                )
                .frame(width: DesignTokens.Icon.list)
                .accessibilityHidden(!entry.isBlocked)
                .accessibilityLabel("a11y.denied")

            Text(rendered.text)
                .font(rendered.treatment == .hash
                    ? .system(size: Metrics.hashFontSize, design: .monospaced)
                    : DesignTokens.Typography.listItem)
                .foregroundStyle(foreground)
                .lineLimit(1)

            Spacer(minLength: 0)

            if showsTime, let modifiedAt = entry.modifiedAt {
                Text(Self.timeFormatter.string(from: modifiedAt))
                    .font(DesignTokens.Typography.path)
                    .monospacedDigit()
                    .foregroundStyle(
                        isSelected && isActive ? foreground : DesignTokens.Ink.tertiary
                    )
                    .frame(width: Metrics.timeColumnWidth, alignment: .trailing)
            }

            star
        }
        .padding(.horizontal, DesignTokens.Row.horizontalInset)
        .frame(height: DesignTokens.Row.listHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Row.cornerRadius, style: .continuous)
                .fill(background)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.name)
        .accessibilityValue(isFavorited ? "a11y.favorite.on" : "a11y.favorite.off")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var star: some View {
        if isFavorited {
            HStack(spacing: DesignTokens.Row.chromeSpacing) {
                starButton(systemName: "star.fill", tint: DesignTokens.Status.favorite)
                if let favoriteShortcut {
                    KeyCapText(favoriteShortcut)
                        .foregroundStyle(
                            isSelected && isActive ? foreground : DesignTokens.Ink.tertiary
                        )
                }
            }
        } else if showsIdleStar {
            starButton(
                systemName: "star",
                tint: isSelected && isActive ? .white : DesignTokens.Ink.tertiary
            )
        }
    }

    private func starButton(systemName: String, tint: Color) -> some View {
        Button(action: onToggleFavorite) {
            Image(systemName: systemName)
                .font(.system(size: DesignTokens.Icon.list))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorited ? "a11y.favorite.remove" : "a11y.favorite.add")
    }
}
