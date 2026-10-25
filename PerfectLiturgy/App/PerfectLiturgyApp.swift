import SwiftData
import SwiftUI

@main
struct PerfectLiturgyApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var design: DesignPreferences
    @State private var navigation = AppNavigation()
    @State private var readings = ReadingsPreferences()
    @State private var packs: InstalledPacks
    @State private var languages = LanguageSelection()
    @State private var session: AppSession

    init() {
        AppFonts.register()
        AppChrome.apply()
        let design = DesignPreferences()
        let packs = InstalledPacks()
        let session = AppSession()
        _design = State(initialValue: design)
        _packs = State(initialValue: packs)
        _session = State(initialValue: session)
        SyncRuntime.configure(session: session, packs: packs, design: design)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(HymnStore.shared)
                .environment(design)
                .environment(navigation)
                .environment(readings)
                .environment(packs)
                .environment(languages)
                .environment(session)
                .environment(\.readingScale, design.readingScale)
                .resolvePalette()
                .preferredColorScheme(design.appearance.colorScheme)
                .wideLayout()
                .onOpenURL { url in
                    Task {
                        await session.accept(url, client: .live, context: HymnStore.shared.mainContext)
                    }
                }
                .task {
                    LinkMonitor.shared.onUpdate = {
                        Task { await SyncController.shared.runAutomatic() }
                    }
                    LinkMonitor.shared.start()
                    BackgroundSync.schedule()
                    await session.restore(client: .live)
                    await NoticeCenter.shared.sessionChanged(accountID: session.profile?.id, bearer: session.token)
                    await SyncController.shared.runAutomatic()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    BackgroundSync.schedule()
                    Task { await SyncController.shared.runAutomatic() }
                }
                .onChange(of: session.token) { _, token in
                    Task { await NoticeCenter.shared.sessionChanged(accountID: session.profile?.id, bearer: token) }
                }
                .onChange(of: session.profile?.id) { _, accountID in
                    Task { await NoticeCenter.shared.sessionChanged(accountID: accountID, bearer: session.token) }
                }
        }
    }
}
