import SwiftUI

/// Site brand wordmark. The source SVG uses live Cinzel, so the artwork here is outlined.
struct Wordmark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(colorScheme == .dark ? "LogoReversed" : "LogoHorizontal")
            .resizable()
            .scaledToFit()
            .frame(height: 20)
            .accessibilityHidden(true)
    }
}

struct Mark: View {
    @Environment(\.colorScheme) private var colorScheme
    var height: CGFloat = 44

    var body: some View {
        Image(colorScheme == .dark ? "LogoSymbolReversed" : "LogoSymbol")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}
