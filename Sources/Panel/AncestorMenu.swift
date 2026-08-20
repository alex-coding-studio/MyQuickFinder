import MyQuickFinderKit
import SwiftUI

struct AncestorMenu: View {
    private enum Metrics {
        static let visibleRows = 8
        static let depthColumnWidth: CGFloat = 18
        static let rowSpacing: CGFloat = 7
        static let containerInset: CGFloat = 6
        static let cornerRadius: CGFloat = 10
    }

    let ancestors: [BreadcrumbSegment]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onConfirm: () -> Void

    private var listHeight: CGFloat {
        CGFloat(min(ancestors.count, Metrics.visibleRows)) * DesignTokens.Row.listHeight
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(ancestors.enumerated()), id: \.element.id) { index, segment in
                        row(segment, isSelected: index == selectedIndex)
                            .id(segment.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(index)
                                onConfirm()
                            }
                    }
                }
            }
            .frame(height: listHeight)
            .onChange(of: selectedIndex, initial: true) { _, _ in
                guard ancestors.indices.contains(selectedIndex) else {
                    return
                }
                proxy.scrollTo(ancestors[selectedIndex].id)
            }
        }
        .padding(Metrics.containerInset)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(DesignTokens.Separator.color, lineWidth: DesignTokens.Separator.width)
        )
        .elevationShadow(DesignTokens.Panel.elevation)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("a11y.ancestors \(ancestors.count)")
    }

    private func row(_ segment: BreadcrumbSegment, isSelected: Bool) -> some View {
        HStack(spacing: Metrics.rowSpacing) {
            Text(verbatim: "\(segment.depth)")
                .font(DesignTokens.Typography.count)
                .monospacedDigit()
                .foregroundStyle(DesignTokens.Ink.tertiary)
                .frame(width: Metrics.depthColumnWidth, alignment: .trailing)
            Text(DisplayName.render(segment.name).text)
                .font(DesignTokens.Typography.listItem)
                .foregroundStyle(DesignTokens.Ink.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Row.horizontalInset)
        .frame(height: DesignTokens.Row.listHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Row.cornerRadius, style: .continuous)
                .fill(isSelected ? DesignTokens.Selection.inactiveFill : .clear)
        )
        .accessibilityLabel("a11y.ancestor.segment \(segment.depth) \(segment.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
