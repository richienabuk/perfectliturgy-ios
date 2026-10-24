import BackgroundTasks
import Foundation
import Network
import SwiftData

@Observable
final class LinkMonitor {
    static let shared = LinkMonitor()

    private(set) var link = LinkKind.offline
    var onUpdate: (() -> Void)?

    private let monitor = NWPathMonitor()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { path in
            let next = LinkKind(
                online: path.status == .satisfied,
                metered: path.isExpensive || path.isConstrained
            )
            Task { @MainActor in
                guard LinkMonitor.shared.link != next else { return }
                LinkMonitor.shared.link = next
                LinkMonitor.shared.onUpdate?()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.perfectliturgy.link"))
    }
}

enum SyncRuntime {
    static var run: @MainActor () async -> SyncReport = {
        SyncReport(outcome: .connection, bookmarksKept: false)
    }

    static func configure(session: AppSession, packs: InstalledPacks, design: DesignPreferences) {
        run = {
            let root = DevotionLibrary.applicationSupport
            let catalog = PackFiles.loadCatalog(root: root)?.packs ?? []
            return await ContentSync.run(
                installed: packs.ids,
                catalog: catalog,
                client: PackClient(
                    transport: LivePackTransport(),
                    apiBase: ServiceOrigin.apiBaseURL,
                    token: session.token
                ),
                context: HymnStore.shared.mainContext,
                packs: packs,
                supportRoot: root,
                defaults: .standard,
                mergeBookmarks: {
                    try await session.mergeBookmarks(client: .live, context: HymnStore.shared.mainContext)
                }
            )
        }
        SyncController.shared.autoSyncEnabled = { design.autoSync }
        SyncController.shared.signedIn = { session.isSignedIn }
    }
}

@Observable
final class SyncController {
    static let shared = SyncController()

    var showsSheet = false
    var phase: SyncPhase = .idle
    var link: () -> LinkKind = { LinkMonitor.shared.link }
    var autoSyncEnabled: () -> Bool = { true }
    var signedIn: () -> Bool = { true }
    var perform: () async -> SyncReport = { await SyncRuntime.run() }

    private var inFlight: Task<SyncReport, Never>?

    func requestManual() async {
        showsSheet = true
        guard signedIn() else {
            phase = .finished(SyncReport(outcome: .needsSignIn, bookmarksKept: false))
            return
        }
        if inFlight == nil { phase = .working }
        await run()
    }

    func runAutomatic() async {
        guard signedIn() else { return }
        guard SyncPolicy.allowsAutomatic(enabled: autoSyncEnabled(), link: link()) else { return }
        await run()
    }

    func cancel() {
        inFlight?.cancel()
    }

    private func run() async {
        if let inFlight {
            _ = await inFlight.value
            return
        }
        phase = .working
        let task = Task { await perform() }
        inFlight = task
        let report = await task.value
        inFlight = nil
        phase = .finished(report)
    }
}

enum SyncPhase: Equatable {
    case idle
    case working
    case finished(SyncReport)
}

enum BackgroundSync {
    static let identifier = "com.perfectliturgy.sync"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                task.expirationHandler = {
                    Task { @MainActor in SyncController.shared.cancel() }
                }
                let allowed = SyncPolicy.allowsAutomatic(
                    enabled: SyncController.shared.autoSyncEnabled(),
                    link: SyncController.shared.link()
                )
                if allowed {
                    await SyncController.shared.runAutomatic()
                }
                let failed = SyncController.shared.phase == .finished(
                    SyncReport(outcome: .connection, bookmarksKept: false)
                ) || SyncController.shared.phase == .finished(
                    SyncReport(outcome: .connection, bookmarksKept: true)
                )
                task.setTaskCompleted(success: !failed)
                schedule()
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
