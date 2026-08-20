import SwiftUI

struct PanelAction: Identifiable {
    let id: String
    let title: String
    let keyCap: String?
    let shortcut: KeyboardShortcut?
    let isPrimary: Bool
    var isEnabled = true
    let perform: () -> Void
}

struct ActionPill: View {
    let action: PanelAction
    let horizontalInset: CGFloat

    private var foreground: Color {
        action.isPrimary ? .white : DesignTokens.Ink.primary
    }

    private var keyCapForeground: Color {
        action.isPrimary ? .white.opacity(BaseTokens.Opacity.heavy) : DesignTokens.Ink.secondary
    }

    var body: some View {
        Button(action: action.perform) {
            HStack(spacing: DesignTokens.Pill.capSpacing) {
                Text(action.title)
                    .font(DesignTokens.Typography.breadcrumbAncestor)
                    .foregroundStyle(foreground)
                if let keyCap = action.keyCap {
                    KeyCapText(keyCap)
                        .foregroundStyle(keyCapForeground)
                }
            }
            .padding(.horizontal, horizontalInset)
            .frame(height: DesignTokens.Pill.height)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Pill.cornerRadius, style: .continuous)
                    .fill(
                        action.isPrimary ? DesignTokens.Selection.active : DesignTokens.Selection.inactiveFill
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .opacity(action.isEnabled ? 1 : DesignTokens.Pill.disabledOpacity)
        .keyboardShortcut(action.shortcut)
        .accessibilityLabel(action.keyCap.map { "\(action.title) \($0)" } ?? action.title)
    }
}

struct ActionBar: View {
    private enum Metrics {
        static let rowSpacing = DesignTokens.Pill.spacing
        static let pathTopInset: CGFloat = 7
        static let pathBottomInset: CGFloat = 9
        static let pathLineLimit = 2
        static let gearSize: CGFloat = 14
    }

    let path: String
    let actions: [PanelAction]
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            Text(path)
                .font(DesignTokens.Typography.path)
                .foregroundStyle(DesignTokens.Ink.tertiary)
                .lineLimit(Metrics.pathLineLimit)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(spacing: DesignTokens.Pill.spacing) {
                ForEach(actions) { action in
                    ActionPill(action: action, horizontalInset: DesignTokens.Pill.compactInset)
                }
                Spacer(minLength: 0)

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: Metrics.gearSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Ink.tertiary)
                .accessibilityLabel("a11y.openSettings")
            }
        }
        .padding(.horizontal, DesignTokens.Row.chromeInset)
        .padding(.top, Metrics.pathTopInset)
        .padding(.bottom, Metrics.pathBottomInset)
    }
}
