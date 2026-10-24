import SwiftData
import SwiftUI

@main
struct PerfectLiturgyApp: App {
    @State private var design = DesignPreferences()
    @State private var navigation = AppNavigation()

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
                .environment(\.readingScale, design.readingScale)
                .resolvePalette()
                .preferredColorScheme(design.appearance.colorScheme)
                .wideLayout()
                .onOpenURL(perform: AuthReturn.handle)
        }
    }
}
