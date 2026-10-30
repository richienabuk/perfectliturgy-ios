import Foundation
import SwiftData
import SwiftUI
import Testing
import UserNotifications
@testable import PerfectLiturgy

@Test func `a hymn delta applies once and readings sync pages until the cursor ends`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let bible = try BibleStore.make(inMemory: true)
    let context = container.mainContext
    let defaults = try #require(UserDefaults(suiteName: "sync-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    packs.install("hymns-en")
    packs.install("readings-test")
    packs.install("order-en")
    let hymns = PackRecord(
        packId: "hymns-en",
        type: "hymns",
        language: "en",
        displayName: "English Hymns",
        revision: "rev-1",
        requiresSignIn: true,
        mode: "live"
    )
    let readings = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        revision: "rev-1",
        requiresSignIn: true,
        mode: "live"
    )
    let order = PackRecord(
        packId: "order-en",
        type: "order",
        language: "en",
        displayName: "Order of Mass · English",
        requiresSignIn: true,
        mode: "download"
    )
    try HymnImporter.importData(originalHymn, into: context)
    PackFiles.storeRevision("rev-1", for: "hymns-en", defaults: defaults)
    PackFiles.storeRevision("rev-1", for: "readings-test", defaults: defaults)
    let installed: Set<String> = ["hymns-en", "readings-test", "order-en"]
    let root = FileManager.default.temporaryDirectory.appending(path: "sync-\(UUID().uuidString)", directoryHint: .isDirectory)
    let transport = SyncScript(bodies: [hymnDelta, readingsPage1, readingsPage2, hymnQuiet, readingsQuiet])
    let client = PackClient(transport: transport, apiBase: URL(string: "https://api.example.test")!, token: "session-1")
    var merged = 0
    let first = await ContentSync.run(
        installed: installed,
        catalog: [hymns, readings, order],
        client: client,
        context: context,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: bible,
        mergeBookmarks: { merged += 1 }
    )
    #expect(first.outcome == .current)
    #expect(merged == 1)
    let revised = try #require(HymnImporter.record(id: "test-en-1", in: context))
    #expect(revised.title == "Test hymn one revised")
    #expect(try context.fetchCount(FetchDescriptor<HymnRecord>()) == 1)
    #expect(transport.requests.count == 3)
    #expect(transport.requests[0].url?.path == "/v1/packs/hymns-en/sync")
    #expect(since(transport.requests[0]) == "rev-1")
    #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer session-1")
    #expect(transport.requests[1].url?.path == "/v1/packs/readings-test/sync")
    #expect(cursor(transport.requests[1]) == nil)
    #expect(cursor(transport.requests[2]) == "cursor-2")
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == "rev-3")
    let verses = try await BibleReader(modelContainer: bible).verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 15
    )
    #expect(verses.map(\.text) == ["Test narration.", "Test verse two"])

    let second = await ContentSync.run(
        installed: installed,
        catalog: [hymns, readings, order],
        client: client,
        context: context,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: bible,
        mergeBookmarks: { merged += 1 }
    )
    #expect(second.outcome == .current)
    #expect(HymnImporter.record(id: "test-en-1", in: context)?.title == "Test hymn one revised")
    #expect(try context.fetchCount(FetchDescriptor<HymnRecord>()) == 1)
    #expect(transport.requests.count == 5)
    #expect(since(transport.requests[3]) == "rev-2")
    #expect(since(transport.requests[4]) == "rev-3")
    #expect(transport.requests.allSatisfy { $0.url?.path.contains("/download") == false })
}

@Test func `sync updates only downloaded hymns and daily readings`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let bible = try BibleStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "sync-download-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    let installed = [
        "hymns-en", "hymns-la", "readings-rsvce", "readings-nab",
        "order-en", "rosary-en", "litanies-en", "stations-en", "prayers-en", "calendar-us",
    ]
    for id in installed { packs.install(id) }
    PackFiles.storeRevision("rev-1", for: "hymns-en", defaults: defaults)
    PackFiles.storeRevision("rev-1", for: "readings-rsvce", defaults: defaults)
    PackFiles.storeRevision("rev-1", for: "order-en", defaults: defaults)
    PackFiles.storeRevision("rev-1", for: "prayers-en", defaults: defaults)
    PackFiles.storeRevision("rev-9", for: "calendar-us", defaults: defaults)
    let catalog = [
        live("hymns-en", type: "hymns"),
        live("hymns-la", type: "hymns"),
        live("readings-rsvce", type: "readings"),
        live("readings-nab", type: "readings"),
        downloadOnly("order-en", type: "order"),
        downloadOnly("rosary-en", type: "rosary"),
        downloadOnly("litanies-en", type: "litanies"),
        downloadOnly("stations-en", type: "stations"),
        downloadOnly("prayers-en", type: "prayers"),
        downloadOnly("calendar-us", type: "calendar"),
    ]
    let transport = SyncScript(bodies: [hymnQuiet, readingsQuietRSVCE])
    let client = PackClient(transport: transport, apiBase: URL(string: "https://api.example.test")!, token: "session-1")
    let report = await ContentSync.run(
        installed: Set(installed),
        catalog: catalog,
        client: client,
        context: container.mainContext,
        packs: packs,
        supportRoot: FileManager.default.temporaryDirectory,
        defaults: defaults,
        bibleContainer: bible,
        mergeBookmarks: {}
    )
    #expect(report.outcome == .current)
    #expect(transport.requests.count == 2)
    let paths = transport.requests.map { $0.url?.path }
    #expect(paths == ["/v1/packs/hymns-en/sync", "/v1/packs/readings-rsvce/sync"])
    #expect(transport.requests.allSatisfy { $0.url?.path.contains("/download") == false })
    #expect(transport.requests.allSatisfy { since($0) == "rev-1" })
}

@Test func `sync re-downloads a calendar when the catalog revision moves`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let bible = try BibleStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "sync-calendar-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    packs.install("calendar-test")
    packs.install("hymns-en")
    PackFiles.storeRevision("rev-1", for: "calendar-test", defaults: defaults)
    PackFiles.storeRevision("rev-1", for: "hymns-en", defaults: defaults)
    let root = FileManager.default.temporaryDirectory
        .appending(path: "sync-cal-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let old = Data("""
    {"pack_id":"calendar-test","type":"calendar","language":"en","revision":"rev-1",
     "display_name":"Test calendar","metadata":{"region":"test"},
     "data":{"days":[{"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18}],
      "formulas":{},"sunday":{},"feria":{},"proper":{}}}
    """.utf8)
    try PackFiles.ensureFolder(root)
    try old.write(to: PackFiles.file(for: "calendar-test", root: root), options: .atomic)

    let calendar = PackRecord(
        packId: "calendar-test",
        type: "calendar",
        language: "en",
        displayName: "Test calendar",
        revision: "rev-2",
        requiresSignIn: false,
        mode: "download",
        metadata: PackMetadata(region: "test")
    )
    let hymns = live("hymns-en", type: "hymns")
    let updated = Data("""
    {"pack_id":"calendar-test","type":"calendar","language":"en","revision":"rev-2",
     "display_name":"Test calendar","metadata":{"region":"test"},
     "data":{"days":[{"id":"test-patron","title":"Test patron revised","color":"red","month":10,"day":18}],
      "formulas":{},"sunday":{},"feria":{},"proper":{}}}
    """.utf8)
    let transport = SyncScript(bodies: [hymnQuiet, updated])
    let client = PackClient(transport: transport, apiBase: URL(string: "https://api.example.test")!, token: "session-1")
    let report = await ContentSync.run(
        installed: ["calendar-test", "hymns-en"],
        catalog: [hymns, calendar],
        client: client,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: bible,
        mergeBookmarks: {}
    )
    #expect(report.outcome == .current)
    #expect(transport.requests.map { $0.url?.path } == [
        "/v1/packs/hymns-en/sync",
        "/v1/packs/calendar-test/download",
    ])
    #expect(PackFiles.revision(for: "calendar-test", defaults: defaults) == "rev-2")
    let loaded = try CalendarPackReader.decode(Data(contentsOf: PackFiles.file(for: "calendar-test", root: root)))
    #expect(loaded.revision == "rev-2")
    #expect(loaded.days.map(\.title) == ["Test patron revised"])
}

@Test func `sync waits for a session before it starts`() async throws {
    let controller = SyncController()
    var calls = 0
    controller.perform = {
        calls += 1
        return SyncReport(outcome: .current, bookmarksKept: false)
    }
    controller.signedIn = { false }
    controller.autoSyncEnabled = { true }
    controller.link = { .wifi }
    await controller.runAutomatic()
    await controller.requestManual()
    #expect(calls == 0)
    #expect(controller.showsSheet == true)
    #expect(controller.phase == .finished(SyncReport(outcome: .needsSignIn, bookmarksKept: false)))

    let container = try HymnStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "sync-signed-out-\(UUID().uuidString)"))
    PackFiles.storeRevision("rev-1", for: "hymns-en", defaults: defaults)
    let transport = SyncScript(bodies: [hymnQuiet])
    let client = PackClient(transport: transport, apiBase: URL(string: "https://api.example.test")!, token: nil)
    let report = await ContentSync.run(
        installed: ["hymns-en"],
        catalog: [live("hymns-en", type: "hymns")],
        client: client,
        context: container.mainContext,
        packs: InstalledPacks(defaults: defaults),
        supportRoot: FileManager.default.temporaryDirectory,
        defaults: defaults,
        mergeBookmarks: {}
    )
    #expect(report.outcome == .needsSignIn)
    #expect(transport.requests.isEmpty)
}

@Test func `auto sync stays quiet on a metered path and manual sync still runs`() async {
    let controller = SyncController()
    var calls = 0
    controller.perform = {
        calls += 1
        return SyncReport(outcome: .current, bookmarksKept: false)
    }
    controller.autoSyncEnabled = { true }
    controller.link = { .cellular }
    await controller.runAutomatic()
    #expect(calls == 0)
    #expect(controller.showsSheet == false)

    controller.link = { .wifi }
    controller.autoSyncEnabled = { false }
    await controller.runAutomatic()
    #expect(calls == 0)

    await controller.requestManual()
    #expect(calls == 1)
    #expect(controller.showsSheet == true)
    #expect(controller.phase == .finished(SyncReport(outcome: .current, bookmarksKept: false)))

    controller.autoSyncEnabled = { true }
    controller.showsSheet = false
    await controller.runAutomatic()
    #expect(calls == 2)
    #expect(controller.showsSheet == false)
}

@Test func `mass times and donate open in safari`() {
    #expect(WebLink.massTimes.host == "mass-times.perfectliturgy.com")
    #expect(WebLink.donate.host == "perfectliturgy.com")
    #expect(WebLink.donate.path == "/donate")
    let navigation = AppNavigation()
    navigation.path.append(AppRoute.settings)
    navigation.open(.massTimes)
    #expect(navigation.safariURL == WebLink.massTimes)
    #expect(navigation.path.count == 1)
    navigation.open(.donate)
    #expect(navigation.safariURL == WebLink.donate)
    #expect(navigation.path.count == 1)
    navigation.requestSync()
    #expect(navigation.syncRequest == 1)
}

@Test func `a notice keeps the open screen and builds a banner`() throws {
    let info: [AnyHashable: Any] = [
        "title": "A message",
        "body": "There is something new in the app.",
        "image": "https://perfectliturgy.com/notices/message.jpg",
    ]
    let notice = try #require(NoticePayload.notice(from: info))
    #expect(notice.title == "A message")
    #expect(notice.body == "There is something new in the app.")
    #expect(notice.imageURL?.host == "perfectliturgy.com")
    #expect(NoticePayload.imageURL(from: "http://perfectliturgy.com/notices/message.jpg") == nil)
    #expect(NoticePayload.imageURL(from: "https://perfectliturgy.com/notices/message.gif") == nil)

    let navigation = AppNavigation()
    navigation.path.append(AppRoute.hymn(id: "test-en-1"))
    let center = NoticeCenter()
    center.present(userInfo: info)
    #expect(center.presented == notice)
    #expect(navigation.path.count == 1)

    let banner = NoticeBanner.content(for: notice)
    #expect(banner.title == "A message")
    #expect(banner.body == "There is something new in the app.")
    #expect(BackgroundSync.identifier == "com.perfectliturgy.sync")
}

@Test func `the device token is sent as ios and again after sign-in`() async throws {
    let defaults = try #require(UserDefaults(suiteName: "devices-\(UUID().uuidString)"))
    let transport = SyncScript(bodies: [
        Data("{\"status\":\"active\"}".utf8),
        Data("{\"status\":\"active\"}".utf8),
    ])
    let center = NoticeCenter()
    center.defaults = defaults
    center.client = DeviceClient(
        transport: transport,
        apiBase: URL(string: "https://api.example.test")!,
        bearer: nil
    )
    await center.tokenArrived("phone-token")
    #expect(transport.requests.count == 1)
    let first = try JSONSerialization.jsonObject(with: try #require(transport.requests[0].httpBody)) as? [String: String]
    #expect(first?["token"] == "phone-token")
    #expect(first?["platform"] == "ios")
    #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == nil)

    await center.tokenArrived("phone-token")
    await center.sessionChanged(accountID: nil, bearer: nil)
    #expect(transport.requests.count == 1)

    await center.sessionChanged(accountID: "user-1", bearer: "session-1")
    #expect(transport.requests.count == 2)
    #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer session-1")
    let second = try JSONSerialization.jsonObject(with: try #require(transport.requests[1].httpBody)) as? [String: String]
    #expect(second?["platform"] == "ios")
}

private func live(_ id: String, type: String) -> PackRecord {
    PackRecord(
        packId: id,
        type: type,
        language: "en",
        displayName: id,
        revision: "rev-9",
        requiresSignIn: true,
        mode: "live"
    )
}

private func downloadOnly(_ id: String, type: String) -> PackRecord {
    PackRecord(
        packId: id,
        type: type,
        language: "en",
        displayName: id,
        revision: "rev-9",
        requiresSignIn: true,
        mode: "download"
    )
}

private func since(_ request: URLRequest) -> String? {
    URLComponents(url: request.url ?? URL(string: "https://api.example.test")!, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first { $0.name == "since" }?
        .value
}

private func cursor(_ request: URLRequest) -> String? {
    URLComponents(url: request.url ?? URL(string: "https://api.example.test")!, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first { $0.name == "cursor" }?
        .value
}

private final class SyncScript: PackTransport {
    var bodies: [Data]
    var requests: [URLRequest] = []

    init(bodies: [Data]) {
        self.bodies = bodies
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let body = bodies.isEmpty ? Data() : bodies.removeFirst()
        let url = request.url ?? URL(string: "https://api.example.test")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private let originalHymn = Data("""
{"revision":"rev-0","data":[{
  "id":"test-en-1","language":"en","hymn_number":9001,"title":"Test hymn one",
  "sections":[{"type":"verse","content":"Test line for hymn one"}]
}]}
""".utf8)

private let hymnDelta = Data("""
{"revision":"rev-2","data":[{
  "id":"test-en-1","language":"en","hymn_number":9001,"title":"Test hymn one revised",
  "sections":[{"type":"verse","content":"Test line for hymn one"}]
}]}
""".utf8)

private let hymnQuiet = Data("""
{"revision":"rev-2","data":[]}
""".utf8)

private let readingsPage1 = Data("""
{"pack_id":"readings-test","type":"readings","language":"en","revision":"rev-3",
 "metadata":{"versification":"lectionary"},
 "books":[{"id":"ISA","order":23,"name":"Isaiah","abbr":"Isa"}],
 "data":[{"book":"ISA","chapter":7,"verse":14,"text":"Test narration.",
   "updated_at":"2026-10-19T12:00:00Z","deleted_at":null}],
 "next_cursor":"cursor-2"}
""".utf8)

private let readingsPage2 = Data("""
{"pack_id":"readings-test","type":"readings","language":"en","revision":"rev-3",
 "data":[{"book":"ISA","chapter":7,"verse":15,"text":"Test verse two",
   "updated_at":"2026-10-19T12:00:01Z","deleted_at":null}]}
""".utf8)

private let readingsQuiet = Data("""
{"pack_id":"readings-test","type":"readings","language":"en","revision":"rev-3","data":[]}
""".utf8)

private let readingsQuietRSVCE = Data("""
{"pack_id":"readings-rsvce","type":"readings","language":"en","revision":"rev-2","data":[]}
""".utf8)
