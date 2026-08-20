import SwiftUI

struct SettingsSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .frame(width: DesignTokens.Settings.width)
        .frame(minHeight: DesignTokens.Settings.contentMinHeight)
    }
}

struct SettingsNote: View {
    let text: String
    let isWarning: Bool

    init(_ text: String, isWarning: Bool = false) {
        self.text = text
        self.isWarning = isWarning
    }

    var body: some View {
        Text(text)
            .foregroundStyle(isWarning ? DesignTokens.Status.denied : DesignTokens.Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
