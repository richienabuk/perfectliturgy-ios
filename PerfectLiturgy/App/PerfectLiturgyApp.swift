import SwiftData
import SwiftUI

@main
struct PerfectLiturgyApp: App {
    @State private var design = DesignPreferences()
    @State private var navigation = AppNavigation()
    @State private var readings = ReadingsPreferences()
    @State private var packs = InstalledPacks()
    @State private var devotions = DevotionSession()

    init() {
        AppFonts.register()
        AppChrome.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(HymnStore.shared)
                .environment(design)
                .environment(navigation)
                .environment(readings)
                .environment(packs)
                .environment(devotions)
                .environment(\.readingScale, design.readingScale)
                .resolvePalette()
                .preferredColorScheme(design.appearance.colorScheme)
                .wideLayout()
                .onOpenURL(perform: AuthReturn.handle)
        }
    }
}
