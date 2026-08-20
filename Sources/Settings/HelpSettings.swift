import MyQuickFinderKit
import SwiftUI

struct HelpSettings: View {
    let bindings: KeyBindings

    var body: some View {
        SettingsSection {
            ForEach(PanelCommandCopy.helpGroups, id: \.title) { group in
                Section {
                    ForEach(group.commands, id: \.self) { command in
                        HStack(alignment: .center) {
                            Text(PanelCommandCopy.title(command))
                            Spacer(minLength: DesignTokens.Settings.rowSpacing)
                            Text(PanelCommandCopy.settingsCap(command, in: bindings))
                                .font(DesignTokens.Typography.keyCap)
                                .foregroundStyle(DesignTokens.Ink.secondary)
                        }
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
    }
}
