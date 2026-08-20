import MyQuickFinderKit
import SwiftUI

struct FavoritesBar: View {
    private enum Metrics {
        static let maxHeight = CGFloat(FavoriteList.shortcutCapacity)
            * DesignTokens.Row.favoriteHeight
            + DesignTokens.Panel.listInsetTop
            + DesignTokens.Panel.listInsetBottom
        static let hintRowHeight: CGFloat = 30
        static let emptyTopInset: CGFloat = 2
        static let emptyBottomInset: CGFloat = 10
        static let headerTopInset: CGFloat = 2
        static let searchIconSize: CGFloat = 13
        static let hintThreshold = 2
    }

    let model: PanelModel
    let bindings: KeyBindings
    let onActivate: (Favorite.ID) -> Void
    let onOpen: (Favorite.ID) -> Void
    let onOpenPicker: () -> Void

    private var favorites: FavoriteList {
        model.favorites
    }

    private var title: String {
        if favorites.isEmpty {
            return String(localized: "favorites.title")
        }
        return String(localized: "favorites.titleWithCount \(favorites.items.count)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if favorites.isEmpty {
                emptyState
            } else {
                rows
                if favorites.items.count <= Metrics.hintThreshold {
                    hint
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(DesignTokens.Typography.sectionHeader)
                .tracking(DesignTokens.Typography.sectionHeaderTracking)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.Ink.secondary)
            Spacer(minLength: 0)
            Button(action: onOpenPicker) {
                HStack(spacing: DesignTokens.Row.contentSpacing - 1) {
                    KeyCapText(PanelCommandCopy.shortCap(.openPicker, in: bindings))
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Metrics.searchIconSize))
                }
                .foregroundStyle(DesignTokens.Ink.tertiary)
                .frame(height: DesignTokens.Row.minimumHitHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.favorites.openPicker")
        }
        .padding(.horizontal, DesignTokens.Row.chromeInset)
        .padding(.top, Metrics.headerTopInset)
        .frame(height: DesignTokens.Row.zoneHeaderHeight)
    }

    private var emptyState: some View {
        (
            Text("favorites.empty.lead")
                + Text(Image(systemName: "star"))
                + Text("favorites.empty.trail")
        )
        .font(DesignTokens.Typography.breadcrumbAncestor)
        .foregroundStyle(DesignTokens.Ink.secondary)
        .lineSpacing(Metrics.emptyTopInset)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Row.proseInset)
        .padding(.top, Metrics.emptyTopInset)
        .padding(.bottom, Metrics.emptyBottomInset)
        .accessibilityLabel("a11y.favorites.empty")
    }

    private var rows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(favorites.items.enumerated()), id: \.element.id) { index, favorite in
                    FavoriteRow(
                        favorite: favorite,
                        isMissing: model.isMissing(favorite),
                        home: model.browser.home,
                        shortcut: FavoriteList.shortcut(at: index),
                        isSelected: favorite.id == favorites.selectedID
                            && model.favoritesSelectionIsActive,
                        isActive: model.browser.keyboardEngaged
                    )
                    .onTapGesture { onActivate(favorite.id) }
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded { onOpen(favorite.id) }
                    )
                    .contextMenu {
                        Button("favorites.remove") { model.removeFavorite(favorite.id) }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Panel.listInsetHorizontal)
            .padding(.top, DesignTokens.Panel.listInsetTop)
            .padding(.bottom, DesignTokens.Panel.listInsetBottom)
        }
        .frame(height: min(
            CGFloat(favorites.items.count) * DesignTokens.Row.favoriteHeight
                + DesignTokens.Panel.listInsetTop + DesignTokens.Panel.listInsetBottom,
            Metrics.maxHeight
        ))
    }

    private var hint: some View {
        Text("favorites.hint")
            .font(DesignTokens.Typography.sectionHeader)
            .foregroundStyle(DesignTokens.Ink.tertiary)
            .padding(.horizontal, DesignTokens.Row.proseInset)
            .frame(height: Metrics.hintRowHeight, alignment: .center)
    }
}

private struct FavoriteRow: View {
    let favorite: Favorite
    let isMissing: Bool
    let home: URL
    let shortcut: String?
    let isSelected: Bool
    let isActive: Bool

    private var symbol: String {
        switch favorite.kind {
        case .directory: "folder"
        case .file: "doc"
        case .script: "terminal"
        }
    }

    private var foreground: Color {
        if isSelected, isActive {
            return .white
        }
        return isMissing ? DesignTokens.Ink.tertiary : DesignTokens.Ink.primary
    }

    private var iconTint: Color {
        if isMissing, !(isSelected && isActive) {
            return DesignTokens.Status.denied
        }
        return foreground
    }

    private var secondary: String {
        PathDisplay.abbreviatingHome(favorite.url.deletingLastPathComponent(), home: home)
    }

    private var accessibilityText: String {
        var parts = [String(localized: "a11y.favorite \(favorite.displayName)")]
        if isMissing {
            parts.append(String(localized: "a11y.favorite.missing"))
        }
        if let shortcut {
            parts.append(shortcut)
        }
        return parts.joined(separator: String(localized: "a11y.separator"))
    }

    var body: some View {
        HStack(spacing: DesignTokens.Row.contentSpacing) {
            Image(systemName: symbol)
                .font(.system(size: DesignTokens.Icon.list))
                .frame(width: DesignTokens.Icon.list)
                .foregroundStyle(iconTint)
            Text(DisplayName.render(favorite.displayName).text)
                .font(DesignTokens.Typography.listItem)
                .foregroundStyle(foreground)
                .strikethrough(isMissing, color: foreground)
                .lineLimit(1)
            Text(secondary)
                .font(DesignTokens.Typography.path)
                .foregroundStyle(isSelected && isActive ? foreground : DesignTokens.Ink.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 0)
            if let shortcut {
                KeyCapText(shortcut)
                    .foregroundStyle(
                        isSelected && isActive ? foreground : DesignTokens.Ink.tertiary
                    )
            }
        }
        .padding(.horizontal, DesignTokens.Row.horizontalInset)
        .frame(height: DesignTokens.Row.favoriteHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Row.cornerRadius, style: .continuous)
                .fill(
                    isSelected ? (
                        isActive ? DesignTokens.Selection.active : DesignTokens.Selection.inactiveFill
                    ) : .clear
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
