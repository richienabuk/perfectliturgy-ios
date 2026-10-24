import SwiftUI

@main
struct PerfectLiturgyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL(perform: AuthReturn.handle)
        }
    }
}
