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
    @State private var bookmarkPush: Task<Void, Never>?

    /// A save or removal reaches the Account soon after it is made, on any connection that works.
    /// Several quick changes send once. A failed push waits for the next sync.
    private func pushBookmarksSoon() {
        guard session.isSignedIn else { return }
        bookmarkPush?.cancel()
        let session = session
        bookmarkPush = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, session.isSignedIn, LinkMonitor.shared.link.online else { return }
            try? await session.mergeBookmarks(client: .live, context: HymnStore.shared.mainContext)
        }
    }

    init() {
        AppFonts.register()
        AppChrome.apply()
        _ = BibleStore.shared
        let design = DesignPreferences()
        let packs = InstalledPacks()
        BibleStore.reconcileInstalled(packs: packs, defaults: .standard)
        let root = DevotionLibrary.applicationSupport
        CalendarPackReader.reconcileInstalled(
            packs: packs,
            defaults: .standard,
            root: root,
            catalog: PackFiles.loadCatalog(root: root)?.packs ?? []
        )
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
                .alert(
                    AccountCopy.confirmTitle,
                    isPresented: Binding(
                        get: { session.incoming != nil },
                        set: { if !$0 { session.declineIncoming() } }
                    ),
                    presenting: session.incoming
                ) { _ in
                    Button(AccountCopy.confirmAction) {
                        Task {
                            await session.confirmIncoming(client: .live, context: HymnStore.shared.mainContext)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { incoming in
                    Text(AccountCopy.confirmMessage(email: incoming.email, replacing: session.profile?.email))
                }
                .onReceive(NotificationCenter.default.publisher(for: .bookmarksDidChange)) { _ in
                    pushBookmarksSoon()
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
