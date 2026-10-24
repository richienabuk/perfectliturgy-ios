import SwiftUI
import Testing
import UIKit
@testable import PerfectLiturgy

@Test func `light and dark floors actions and emphasis match the tokens`() {
    #expect(Palette.light.background.hex == 0xF6F1E7)
    #expect(Palette.dark.background.hex == 0x111C17)
    #expect(Palette.light.primary.hex == 0x1F4D3B)
    #expect(Palette.dark.primary.hex == 0xE3B25A)
    #expect(Palette.light.emphasis.hex == 0xA63E1B)
    #expect(Palette.dark.emphasis.hex == 0xE8906A)
    #expect(Palette.light.primaryForeground.hex == 0xF6F1E7)
    #expect(Palette.dark.primaryForeground.hex == 0x1C2A24)
}

@Test func `stanza refrain and the liturgical banner keep their fills`() {
    #expect(Palette.light.stanza.hex == 0xF8F4EB)
    #expect(Palette.dark.stanza.hex == 0x1B2A22)
    #expect(Palette.light.refrain.hex == 0xEDF0E7)
    #expect(Palette.dark.refrain.hex == 0x253A2E)
    #expect(Palette.light.liturgicalBackground == Palette.dark.liturgicalBackground)
    #expect(Palette.light.liturgicalForeground.hex == 0xF6F1E7)
    #expect(Palette.light.liturgicalAccent.hex == 0xE3B25A)
    #expect(Palette.dark.liturgicalAccent == Palette.light.liturgicalAccent)
}

@Test func `reading scale defaults to one and stays inside the range`() {
    let scale = ReadingScale()
    #expect(scale.headings == 1)
    #expect(scale.body == 1)
    #expect(ReadingScale(headings: 2, body: 0).headings == 1.4)
    #expect(ReadingScale(headings: 2, body: 0).body == 0.8)
}

@Test func `reading roles follow the heading and body sliders`() {
    let scale = ReadingScale(headings: 1.2, body: 0.8)
    #expect(scale.size(for: .partTitle) == 38.4)
    #expect(scale.size(for: .prayer) == 12.8)
    #expect(scale.size(for: .response) == 12.8)
    // Cormorant stays at 24pt even when the heading slider would go under it.
    #expect(ReadingScale(headings: 0.8).size(for: .itemTitle) == 24)
    #expect(ReadingScale().size(for: .itemTitle) == 26)
}

@Test func `a button is at least 44 points and presses to 0.97`() {
    #expect(ControlMetrics.minimumHeight >= 44)
    #expect(ControlMetrics.pressScale == 0.97)
    #expect(ControlMetrics.pressDuration == 0.15)
    #expect(Radius.sheet == 18)
    #expect([Radius.sm, Radius.md, Radius.lg] == [4, 6, 8])
}

@Test func `wide layout needs both 840 width and 600 height`() {
    #expect(LayoutSpan.isWide(width: 840, height: 600))
    #expect(!LayoutSpan.isWide(width: 839, height: 600))
    #expect(!LayoutSpan.isWide(width: 840, height: 599))
}

@Test func `a tablet stays at two columns`() {
    #expect(LayoutSpan.isWide(width: 1366, height: 1024))
    #expect(!LayoutSpan.splitsColumns(width: 1366, height: 1024))
    #expect(LayoutSpan.isWide(width: 1024, height: 1366))
    #expect(!LayoutSpan.splitsColumns(width: 1024, height: 1366))
    #expect(LayoutSpan.splitsColumns(width: 1400, height: 900))
    #expect(!LayoutSpan.splitsColumns(width: 1399, height: 900))
}

@Test func `system appearance follows the device`() {
    #expect(AppearanceMode.system.colorScheme == nil)
    #expect(AppearanceMode.light.colorScheme == .light)
    #expect(AppearanceMode.dark.colorScheme == .dark)
}

@Test func `bundled fonts register`() {
    let bundle = Bundle(for: DesignPreferences.self)
    AppFonts.register(bundle: bundle)
    for name in AppFonts.postScriptNames {
        #expect(UIFont(name: name, size: 16) != nil)
    }
}
