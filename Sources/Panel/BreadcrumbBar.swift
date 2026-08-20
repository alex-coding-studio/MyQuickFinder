import MyQuickFinderKit
import SwiftUI

struct BreadcrumbBar: View {
    private enum Metrics {
        static let hintHeight: CGFloat = 17
        static let hintInset: CGFloat = 6
        static let hintCornerRadius = CXLayoutBridge.hintCornerRadius
        static let lockSize: CGFloat = 12
        static let rootIconSize: CGFloat = 13
        static let collapsedPillInset: CGFloat = 4
    }

    let breadcrumb: Breadcrumb
    let trailingLabel: String?
    let showsParentHint: Bool
    let parentCap: String
    let isDenied: Bool
    let onJump: (URL) -> Void
    let onExpandAncestors: () -> Void
    let onGoUp: () -> Void

    private var totalDepth: Int {
        breadcrumb.ancestors.count + (breadcrumb.trailing.isEmpty ? 0 : 1)
    }

    var body: some View {
        HStack(spacing: DesignTokens.Row.chromeSpacing) {
            rootButton
            if breadcrumb.isCollapsed {
                separator
                collapsedPill
            }
            ForEach(breadcrumb.trailing) { segment in
                separator
                segmentButton(segment, isCurrent: segment == breadcrumb.current)
            }
            Spacer(minLength: 0)
            if isDenied {
                Image(systemName: "lock.fill")
                    .font(.system(size: Metrics.lockSize))
                    .foregroundStyle(DesignTokens.Status.denied)
                    .accessibilityLabel("a11y.denied")
            }
            if showsParentHint {
                parentHint
            }
            if let trailingLabel {
                Text(trailingLabel)
                    .font(DesignTokens.Typography.count)
                    .foregroundStyle(DesignTokens.Ink.tertiary)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .frame(height: DesignTokens.Row.breadcrumbHeight)
        .padding(.horizontal, DesignTokens.Row.chromeInset)
    }

    private var rootButton: some View {
        Button {
            onJump(breadcrumb.root.url)
        } label: {
            Image(systemName: breadcrumb.root.name == "~" ? "house" : "externaldrive")
                .font(.system(size: Metrics.rootIconSize))
                .foregroundStyle(DesignTokens.Ink.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("a11y.breadcrumb.root \(totalDepth) \(breadcrumb.root.name)")
    }

    private var separator: some View {
        Text(verbatim: "/")
            .font(DesignTokens.Typography.breadcrumbAncestor)
            .foregroundStyle(DesignTokens.Ink.tertiary)
    }

    private var parentHint: some View {
        Button(action: onGoUp) {
            parentHintLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel("a11y.breadcrumb.parent \(parentCap)")
    }

    private var parentHintLabel: some View {
        HStack(spacing: DesignTokens.Row.chromeSpacing) {
            Text("breadcrumb.parent")
                .font(DesignTokens.Typography.count)
            KeyCapText(parentCap)
        }
        .foregroundStyle(DesignTokens.Ink.secondary)
        .padding(.horizontal, Metrics.hintInset)
        .frame(height: Metrics.hintHeight)
        .background(
            RoundedRectangle(cornerRadius: Metrics.hintCornerRadius, style: .continuous)
                .fill(DesignTokens.Selection.inactiveFill)
        )
        .fixedSize()
        .contentShape(Rectangle())
    }

    private var collapsedPill: some View {
        Button(action: onExpandAncestors) {
            Text(verbatim: "…")
                .font(DesignTokens.Typography.breadcrumbAncestor)
                .foregroundStyle(DesignTokens.Ink.secondary)
                .padding(.horizontal, Metrics.collapsedPillInset)
                .background(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Row.cornerRadius,
                        style: .continuous
                    )
                    .fill(DesignTokens.Selection.inactiveFill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("a11y.breadcrumb.expand \(breadcrumb.collapsed.count)")
    }

    private func segmentButton(_ segment: BreadcrumbSegment, isCurrent: Bool) -> some View {
        Button {
            onJump(segment.url)
        } label: {
            Text(DisplayName.render(segment.name).text)
                .font(isCurrent
                    ? DesignTokens.Typography.breadcrumbCurrent
                    : DesignTokens.Typography.breadcrumbAncestor)
                .foregroundStyle(isCurrent ? DesignTokens.Ink.primary : DesignTokens.Ink.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "a11y.breadcrumb.segment \(segment.depth) \(totalDepth) \(segment.name)"
        )
    }
}

private enum CXLayoutBridge {
    static let hintCornerRadius: CGFloat = 4
}
