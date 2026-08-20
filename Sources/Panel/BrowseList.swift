import MyQuickFinderKit
import SwiftUI

struct BrowseList: View {
    let model: PanelModel
    let bindings: KeyBindings
    let onSelect: (Int) -> Void
    let onToggleFavorite: (Int) -> Void
    let onOpen: () -> Void
    let onToggleHidden: () -> Void

    private var browser: BrowserModel {
        model.browser
    }

    private var height: CGFloat {
        let rows = CGFloat(browser.entries.count) * DesignTokens.Row.listHeight
        let hint = browser.arranged.hiddenCount > 0 ? DesignTokens.Row.sectionHeaderHeight : 0
        let insets = DesignTokens.Panel.listInsetTop + DesignTokens.Panel.listInsetBottom
        return min(rows + hint + insets, DesignTokens.Panel.listMaxHeight)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(browser.entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, at: index)
                    }
                    if browser.arranged.hiddenCount > 0 {
                        hiddenHint
                    }
                }
                .padding(.horizontal, DesignTokens.Panel.listInsetHorizontal)
                .padding(.top, DesignTokens.Panel.listInsetTop)
                .padding(.bottom, DesignTokens.Panel.listInsetBottom)
            }
            .frame(height: height)
            .onChange(of: browser.selectionIndex) { _, _ in
                guard let id = browser.selectedEntry?.id else {
                    return
                }
                proxy.scrollTo(id)
            }
        }
    }

    private var hiddenHint: some View {
        Button(action: onToggleHidden) {
            hiddenHintLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel("a11y.hidden.show \(browser.arranged.hiddenCount)")
    }

    private var hiddenHintLabel: some View {
        HStack {
            Text("list.hidden \(browser.arranged.hiddenCount)")
            Spacer(minLength: 0)
            KeyCapText(PanelCommandCopy.shortCap(.toggleHidden, in: bindings))
        }
        .font(DesignTokens.Typography.sectionHeader)
        .foregroundStyle(DesignTokens.Ink.tertiary)
        .padding(.horizontal, DesignTokens.Row.horizontalInset)
        .frame(height: DesignTokens.Row.sectionHeaderHeight)
        .contentShape(Rectangle())
    }

    private func row(_ entry: DirectoryEntry, at index: Int) -> some View {
        EntryRow(
            entry: entry,
            showsTime: browser.arranged.showsTimeColumn,
            isSelected: index == browser.selectionIndex && model.listSelectionIsActive,
            isActive: browser.keyboardEngaged,
            isFavorited: model.favorites.contains(url: entry.url),
            favoriteShortcut: model.favorites.index(of: entry.url).flatMap(FavoriteList.shortcut),
            canFavorite: true,
            onToggleFavorite: { onToggleFavorite(index) }
        )
        .id(entry.id)
        .onTapGesture { onSelect(index) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
    }
}
