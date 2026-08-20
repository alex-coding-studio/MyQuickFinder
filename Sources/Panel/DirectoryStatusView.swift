import MyQuickFinderKit
import SwiftUI

struct MissingDirectoryView: View {
    private enum Metrics {
        static let stackSpacing = BaseTokens.Spacing.inline
    }

    let directory: URL
    let home: URL

    var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: DesignTokens.Icon.status))
                .foregroundStyle(DesignTokens.Status.denied)
            Text("status.missing.title")
                .font(DesignTokens.Typography.breadcrumbCurrent)
                .foregroundStyle(DesignTokens.Ink.primary)
            Text(PathDisplay.abbreviatingHome(directory, home: home))
                .font(DesignTokens.Typography.path)
                .foregroundStyle(DesignTokens.Ink.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.Panel.statusHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("status.missing.title")
    }
}

struct EmptyDirectoryView: View {
    var body: some View {
        Text("status.empty")
            .font(DesignTokens.Typography.breadcrumbAncestor)
            .foregroundStyle(DesignTokens.Ink.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Panel.statusHeight)
    }
}

struct DeniedDirectoryView: View {
    private enum Metrics {
        static let stackSpacing = BaseTokens.Spacing.inline
        static let topInset: CGFloat = 18
        static let horizontalInset: CGFloat = 22
        static let bottomInset: CGFloat = 20
        static let buttonRowTopInset = BaseTokens.Spacing.micro
    }

    let directory: URL
    let isSystemProtected: Bool
    let needsRelaunch: Bool
    let onAuthorize: () -> Void
    let finderAction: PanelAction?

    private var explanation: String {
        if isSystemProtected {
            return String(localized: "status.denied.system")
        }
        return String(localized: "status.denied.permissions")
    }

    private var primaryAction: PanelAction {
        needsRelaunch
            ? PanelAction(
                id: "relaunch",
                title: String(localized: "status.denied.relaunch"),
                keyCap: nil,
                shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]),
                isPrimary: true,
                perform: SystemActions.relaunch
            )
            : PanelAction(
                id: "authorize",
                title: String(localized: "status.denied.authorize"),
                keyCap: nil,
                shortcut: KeyboardShortcut("g", modifiers: [.command, .shift]),
                isPrimary: true,
                perform: {
                    onAuthorize()
                    SystemActions.openFullDiskAccessSettings()
                }
            )
    }

    var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            Image(systemName: "lock.fill")
                .font(.system(size: DesignTokens.Icon.status))
                .foregroundStyle(DesignTokens.Status.denied)
            Text("status.denied.title \(SystemActions.localizedDisplayName(for: directory))")
                .font(DesignTokens.Typography.breadcrumbCurrent)
                .foregroundStyle(DesignTokens.Ink.primary)
            Text(needsRelaunch ? String(localized: "status.denied.relaunchNote") : explanation)
                .font(DesignTokens.Typography.breadcrumbAncestor)
                .foregroundStyle(DesignTokens.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DesignTokens.Pill.spacing) {
                ActionPill(action: primaryAction, horizontalInset: DesignTokens.Pill.inset)
                if let finderAction {
                    ActionPill(action: finderAction, horizontalInset: DesignTokens.Pill.inset)
                }
            }
            .padding(.top, Metrics.buttonRowTopInset)
        }
        .padding(.top, Metrics.topInset)
        .padding(.horizontal, Metrics.horizontalInset)
        .padding(.bottom, Metrics.bottomInset)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("a11y.denied")
    }
}

struct LoadingDirectoryView: View {
    private enum Metrics {
        static let skeletonRows = 6
        static let skeletonFill = BaseTokens.Opacity.faint
        static let widthRatios: [Double] = [0.62, 0.44, 0.71, 0.38, 0.55, 0.48]
    }

    let showsSkeleton: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsSkeleton {
                ForEach(0 ..< Metrics.skeletonRows, id: \.self) { index in
                    skeletonRow(ratio: Metrics.widthRatios[index % Metrics.widthRatios.count])
                }
            } else {
                Color.clear.frame(height: DesignTokens.Row.listHeight)
            }
        }
        .padding(.horizontal, DesignTokens.Panel.listInsetHorizontal)
        .padding(.top, DesignTokens.Panel.listInsetTop)
        .padding(.bottom, DesignTokens.Panel.listInsetBottom)
        .accessibilityLabel("a11y.loading")
    }

    private func skeletonRow(ratio: Double) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: DesignTokens.Row.cornerRadius, style: .continuous)
                .fill(DesignTokens.Ink.primary.opacity(Metrics.skeletonFill))
                .frame(width: proxy.size.width * ratio, height: DesignTokens.Icon.list)
                .frame(height: DesignTokens.Row.listHeight, alignment: .center)
        }
        .frame(height: DesignTokens.Row.listHeight)
        .padding(.horizontal, DesignTokens.Row.horizontalInset)
    }
}
