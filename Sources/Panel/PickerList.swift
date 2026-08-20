import MyQuickFinderKit
import SwiftUI

struct PickerList: View {
    let model: PanelModel
    let onOpen: () -> Void
    let onToggleFavorite: (DirectoryEntry) -> Void

    private var picker: PathPickerModel {
        model.picker
    }

    var body: some View {
        if case let .listing(entries) = picker.state {
            results(entries)
        } else {
            PathStatusView(state: picker.state)
        }
    }

    private func results(_ entries: [DirectoryEntry]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, at: index)
                    }
                }
                .padding(.horizontal, DesignTokens.Panel.listInsetHorizontal)
                .padding(.top, DesignTokens.Panel.listInsetTop)
                .padding(.bottom, DesignTokens.Panel.listInsetBottom)
            }
            .frame(height: height(entries.count))
            .onChange(of: picker.selectionIndex, initial: true) { _, _ in
                guard let id = picker.selectedEntry?.id else {
                    return
                }
                proxy.scrollTo(id)
            }
        }
    }

    private func row(_ entry: DirectoryEntry, at index: Int) -> some View {
        PathEntryRow(
            entry: entry,
            isSelected: index == picker.highlightedIndex,
            isFavorited: model.favorites.contains(url: entry.url),
            onToggleFavorite: { onToggleFavorite(entry) }
        )
        .id(entry.id)
        .onTapGesture { picker.selectRow(index) }
        .simultaneousGesture(TapGesture(count: 2).onEnded(onOpen))
    }

    private func height(_ count: Int) -> CGFloat {
        let rows = CGFloat(count) * DesignTokens.Row.listHeight
        let insets = DesignTokens.Panel.listInsetTop + DesignTokens.Panel.listInsetBottom
        return min(rows + insets, DesignTokens.Panel.listMaxHeight)
    }
}
