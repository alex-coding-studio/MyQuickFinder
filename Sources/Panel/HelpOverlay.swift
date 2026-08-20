import AppKit
import MyQuickFinderKit
import SwiftUI

struct HelpOverlay: View {
    private enum Metrics {
        static let rowSpacing: CGFloat = 5
        static let keyColumnWidth: CGFloat = 112
        static let backdrop = BaseTokens.Opacity.heavy
    }

    @State private var monitor: Any?

    let bindings: KeyBindings
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack {
                Text("help.title")
                    .font(DesignTokens.Typography.sectionHeader)
                    .tracking(DesignTokens.Typography.sectionHeaderTracking)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Text("help.dismiss")
                    .font(DesignTokens.Typography.sectionHeader)
            }
            .foregroundStyle(DesignTokens.Ink.tertiary)

            ForEach(PanelCommandCopy.helpOrder, id: \.self) { command in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    KeyCapText(PanelCommandCopy.settingsCap(command, in: bindings))
                        .foregroundStyle(DesignTokens.Ink.primary)
                        .frame(width: Metrics.keyColumnWidth, alignment: .leading)
                    Text(PanelCommandCopy.title(command))
                        .font(DesignTokens.Typography.breadcrumbAncestor)
                        .foregroundStyle(DesignTokens.Ink.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DesignTokens.Settings.inset)
        .frame(width: DesignTokens.Panel.width, alignment: .leading)
        .background(.regularMaterial.opacity(Metrics.backdrop))
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                if !event.modifierFlags.contains(.command) {
                    onDismiss()
                }
                return event
            }
        }
        .onDisappear {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("a11y.help")
    }
}
