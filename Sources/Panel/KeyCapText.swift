import SwiftUI

struct KeyCapText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.keyCap)
    }
}
