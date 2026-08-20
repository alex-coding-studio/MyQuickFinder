import MyQuickFinderKit
import SwiftUI

struct PathPickerBar: View {
    private enum Metrics {
        static let iconSize: CGFloat = 13
    }

    let model: PathPickerModel
    let onChord: (KeyChord, PathFieldFacts) -> Bool
    let exitCap: String
    let onExit: () -> Void

    private var trailingLabel: String? {
        switch model.state {
        case .loading: nil
        case let .listing(entries): String(localized: "panel.count \(entries.count)")
        case .empty: String(localized: "picker.status.empty")
        case .denied: String(localized: "picker.status.denied")
        case .missing: String(localized: "picker.status.missing")
        case .failed: String(localized: "picker.status.failed")
        }
    }

    var body: some View {
        HStack(spacing: DesignTokens.Row.chromeSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.iconSize))
                .foregroundStyle(DesignTokens.Ink.secondary)

            PathTextField(
                text: model.text,
                suggestion: model.inlineSuggestion,
                placeholder: String(localized: "picker.placeholder"),
                selectAllToken: model.activationCount,
                onEdit: { newValue in model.updateText(newValue) },
                onChord: onChord
            )

            if let trailingLabel {
                Text(trailingLabel)
                    .font(DesignTokens.Typography.count)
                    .foregroundStyle(DesignTokens.Ink.tertiary)
                    .monospacedDigit()
                    .fixedSize()
            }
            Button(action: onExit) {
                KeyCapText(exitCap)
                    .foregroundStyle(DesignTokens.Ink.tertiary)
                    .frame(height: DesignTokens.Row.minimumHitHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.picker.exit")
        }
        .frame(height: DesignTokens.Row.breadcrumbHeight)
        .padding(.horizontal, DesignTokens.Row.chromeInset)
    }
}

struct PathEntryRow: View {
    @State private var isHovered = false

    let entry: DirectoryEntry
    let isSelected: Bool
    let isFavorited: Bool
    let onToggleFavorite: () -> Void

    private var foreground: Color {
        isSelected ? .white : DesignTokens.Ink.primary
    }

    private var symbol: String {
        if entry.isBlocked {
            return "lock.fill"
        }
        return entry.isDirectory ? "folder" : "doc"
    }

    var body: some View {
        HStack(spacing: DesignTokens.Row.contentSpacing) {
            Image(systemName: symbol)
                .font(.system(size: DesignTokens.Icon.list))
                .frame(width: DesignTokens.Icon.list)
                .foregroundStyle(
                    entry.isBlocked && !isSelected ? DesignTokens.Status.denied : foreground
                )
            Text(DisplayName.render(entry.name).text)
                .font(DesignTokens.Typography.listItem)
                .foregroundStyle(foreground)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isFavorited || isHovered || isSelected {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .font(.system(size: DesignTokens.Icon.list))
                        .foregroundStyle(isFavorited
                            ? DesignTokens.Status.favorite
                            : (isSelected ? .white : DesignTokens.Ink.tertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorited ? "a11y.favorite.remove" : "a11y.favorite.add")
            }
        }
        .padding(.horizontal, DesignTokens.Row.horizontalInset)
        .frame(height: DesignTokens.Row.listHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Row.cornerRadius, style: .continuous)
                .fill(isSelected ? DesignTokens.Selection.active : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PathStatusView: View {
    let state: PathPickerState

    private var message: String? {
        switch state {
        case .loading: nil
        case .empty: String(localized: "picker.empty")
        case .denied: String(localized: "picker.denied")
        case .missing: String(localized: "picker.missing")
        case let .failed(reason): String(localized: "picker.failed \(reason)")
        case .listing: nil
        }
    }

    private var placeholderHeight: CGFloat {
        DesignTokens.Row.listHeight
            + DesignTokens.Panel.listInsetTop
            + DesignTokens.Panel.listInsetBottom
    }

    var body: some View {
        if let message {
            Text(message)
                .font(DesignTokens.Typography.breadcrumbAncestor)
                .foregroundStyle(DesignTokens.Ink.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Panel.statusHeight)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: placeholderHeight)
        }
    }
}
