import SwiftUI

/// The wordmark is live Cinzel. The symbol beside it stays the outlined brand mark.
struct Wordmark: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Text("PERFECTLITURGY")
            .font(AppFont.wordmark())
            .tracking(AppFont.wordmarkTracking)
            .foregroundStyle(palette.foreground.color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
