import SwiftUI
import UIKit

/// A design-token colour. Components read a `Palette` and never a raw hex.
nonisolated struct Shade: Equatable, Hashable, Sendable {
    var hex: UInt32

    init(_ hex: UInt32) {
        self.hex = hex
    }

    var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    var blue: Double { Double(hex & 0xFF) / 255 }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

nonisolated struct Palette: Equatable, Sendable {
    var background: Shade
    var foreground: Shade
    var card: Shade
    var muted: Shade
    var mutedForeground: Shade
    var primary: Shade
    var primaryForeground: Shade
    var secondary: Shade
    var secondaryForeground: Shade
    var destructive: Shade
    var border: Shade
    var input: Shade
    var emphasis: Shade
    var stanza: Shade
    var refrain: Shade
    var liturgicalBackground: Shade
    var liturgicalForeground: Shade
    var liturgicalAccent: Shade

    static let light = Palette(
        background: Shade(0xF6F1E7),
        foreground: Shade(0x1C2A24),
        card: Shade(0xFBF8F1),
        muted: Shade(0xEEE7D6),
        mutedForeground: Shade(0x56615A),
        primary: Shade(0x1F4D3B),
        primaryForeground: Shade(0xF6F1E7),
        secondary: Shade(0xE8DFCA),
        secondaryForeground: Shade(0x1F4D3B),
        destructive: Shade(0xA12A1C),
        border: Shade(0xD8CFB9),
        input: Shade(0x8A8068),
        emphasis: Shade(0xA63E1B),
        stanza: Shade(0xF8F4EB),
        refrain: Shade(0xEDF0E7),
        liturgicalBackground: Shade(0x1F4D3B),
        liturgicalForeground: Shade(0xF6F1E7),
        liturgicalAccent: Shade(0xE3B25A)
    )

    static let dark = Palette(
        background: Shade(0x111C17),
        foreground: Shade(0xF1EBDD),
        card: Shade(0x18261F),
        muted: Shade(0x2A2820),
        mutedForeground: Shade(0xB3BDB5),
        primary: Shade(0xE3B25A),
        primaryForeground: Shade(0x1C2A24),
        secondary: Shade(0x2A2820),
        secondaryForeground: Shade(0xF1EBDD),
        destructive: Shade(0xA12A1C),
        border: Shade(0x2C4036),
        input: Shade(0x6F8B7C),
        emphasis: Shade(0xE8906A),
        stanza: Shade(0x1B2A22),
        refrain: Shade(0x253A2E),
        liturgicalBackground: Shade(0x1F4D3B),
        liturgicalForeground: Shade(0xF6F1E7),
        liturgicalAccent: Shade(0xE3B25A)
    )

    static func resolve(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }

    static func dynamic(_ pick: @escaping @Sendable (Palette) -> Shade) -> UIColor {
        UIColor { traits in
            let palette = traits.userInterfaceStyle == .dark ? Palette.dark : .light
            return pick(palette).uiColor
        }
    }
}

nonisolated struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension View {
    /// Resolves the palette from the colour scheme already chosen for this view.
    func resolvePalette() -> some View {
        modifier(PaletteResolver())
    }
}

private struct PaletteResolver: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.palette, Palette.resolve(colorScheme))
    }
}
