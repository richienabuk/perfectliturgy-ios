import Foundation
import SwiftData
import Testing
@testable import PerfectLiturgy

@Test func `a missing api address stays on the production host`() {
    #expect(ServiceOrigin.url(from: nil) == ServiceOrigin.production)
    #expect(ServiceOrigin.url(from: "not a url") == ServiceOrigin.production)
    #expect(ServiceOrigin.url(from: "http://example.test") == ServiceOrigin.production)
    let development = ServiceOrigin.url(from: "https://perfectliturgyapi.richienabuk.top")
    #expect(development.host == "perfectliturgyapi.richienabuk.top")
}

@Test func `hymn languages use the catalogue language name and display name`() {
    let efik = PackRecord(
        packId: "hymns-efik",
        type: "hymns",
        language: "efik",
        languageName: "Efik",
        displayName: "Efik Hymns",
        mode: "live"
    )
    #expect(HymnLanguage.name(for: "efik", in: [efik]) == "Efik")
    #expect(HymnLanguage.catalogueName(for: "efik", in: [efik]) == "Efik Hymns")
    let hausa = PackRecord(
        packId: "hymns-ha",
        type: "hymns",
        language: "ha",
        displayName: "Hausa Hymns",
        mode: "live"
    )
    // No `language_name`: the pack's display name is the label. The app never parses it.
    #expect(HymnLanguage.name(for: "ha", in: [hausa]) == "Hausa Hymns")
    // A language the pack list does not name shows its code. The app holds no language table.
    #expect(HymnLanguage.name(for: "yo") == "yo")
}

@Test func `the debug app calls the development api`() {
    let api = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
    let auth = Bundle.main.object(forInfoDictionaryKey: "AuthBaseURL") as? String
    #expect(api == "https://perfectliturgyapi.richienabuk.top")
    #expect(auth == "https://perfectliturgyapi.richienabuk.top")
}

@Test func `downloads list the live catalog, and the english and latin seeds when it cannot`() async throws {
    let live = Data("""
    {"data":[
      {"pack_id":"readings-rsv","type":"readings","display_name":"RSV","revision":"2026-01-01T00:00:00.000Z","size":1200000,"requires_sign_in":false,"mode":"live","language":"en"},
      {"pack_id":"hymns-efi","type":"hymns","display_name":"Efik Hymns","revision":"","mode":"live","language":"efi","language_name":"Efik"},
      {"pack_id":"calendar-nigeria","type":"calendar","language":"ng","display_name":"Nigeria","revision":"2026-01-01T00:00:00.000Z","requires_sign_in":true,"mode":"download"}
    ],"page":1,"pageSize":3,"total":3}
    """.utf8)
    let root = try temporaryPackRoot()
    let transport = ScriptTransport(pages: [live])
    let client = PackClient(transport: transport, apiBase: ServiceOrigin.production, token: nil)
    let listed = await PackInstaller.catalog(client: client, supportRoot: root)
    #expect(listed.first { $0.packId == "hymns-efi" }?.languageName == "Efik")
    #expect(listed.contains { $0.packId == "hymns-efi" })
    #expect(listed.first { $0.packId == "hymns-efi" }?.requiresSignIn == true)
    #expect(PackSize.text(1_200_000) == "1.2 MB")
    let titles = PackSections.group(listed).map(\.title)
    #expect(titles == ["Daily Readings", "Calendars", "Hymns"])
    #expect(PackLocale.recommendedCalendar(in: listed, region: "NG")?.packId == "calendar-nigeria")
    let byID = PackRecord(packId: "calendar-ke", type: "calendar", language: nil, displayName: "Kenya", mode: "download")
    #expect(PackLocale.recommendedCalendar(in: [byID], region: "KE")?.packId == "calendar-ke")
    #expect(PackLocale.recommendedCalendar(in: [byID], region: "NG") == nil)

    let offlineRoot = try temporaryPackRoot()
    let offline = ScriptTransport(pages: [], fails: true)
    let offlineClient = PackClient(transport: offline, apiBase: ServiceOrigin.production, token: nil)
    let seeds = await PackInstaller.catalog(client: offlineClient, supportRoot: offlineRoot)
    let ids = Set(seeds.map(\.packId))
    #expect(ids.contains("hymns-en"))
    #expect(ids.contains("hymns-la"))
    #expect(ids.contains("order-en"))
    #expect(ids.contains("rosary-la"))
    #expect(!ids.contains { $0.hasPrefix("readings-") })
    #expect(!ids.contains("hymns-efi"))

    try PackFiles.saveCatalog(
        [PackRecord(packId: "hymns-efi", type: "hymns", language: "efi", displayName: "Efik Hymns", mode: "live")],
        root: offlineRoot
    )
    let stored = await PackInstaller.catalog(client: offlineClient, supportRoot: offlineRoot)
    #expect(stored.map(\.packId) == ["hymns-efi"])
    let saved = try #require(PackFiles.loadCatalog(root: offlineRoot))
    #expect(saved.packs.map(\.packId) == ["hymns-efi"])
    #expect(saved.updatedAt != nil)
    #expect(PackFiles.rowsForDisplay(root: offlineRoot).map(\.packId) == ["hymns-efi"])

    let legacy = try temporaryPackRoot()
    let legacyPack = PackRecord(
        packId: "hymns-ig",
        type: "hymns",
        language: "ig",
        displayName: "Igbo Hymns",
        mode: "live"
    )
    let legacyData = try JSONEncoder().encode([legacyPack])
    try legacyData.write(to: PackFiles.catalogFile(root: legacy), options: .atomic)
    let legacyCatalog = try #require(PackFiles.loadCatalog(root: legacy))
    #expect(legacyCatalog.packs.map(\.packId) == ["hymns-ig"])
    #expect(legacyCatalog.updatedAt == nil)
    #expect(PackFiles.rowsForDisplay(root: legacy).map(\.packId) == ["hymns-ig"])
}

@Test func `removing english hymns hides them, and installing the pack brings them back`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let bundle = Bundle(for: DesignPreferences.self)
    let url = try #require(HymnBundles.url(for: "hymns_en", in: bundle))
    let body = try Data(contentsOf: url)
    try HymnImporter.importData(body, into: context)
    let defaults = UserDefaults(suiteName: "pack-hymns-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryPackRoot()
    let english = try #require(context.fetch(FetchDescriptor<HymnRecord>()).first { $0.id == "test-en-1" })
    #expect(visibleHymns(in: context, packs: packs).contains { $0.id == english.id })

    let pack = PackRecord(
        packId: "hymns-en",
        type: "hymns",
        language: "en",
        displayName: "English Hymns",
        requiresSignIn: false,
        mode: "live"
    )
    try PackInstaller.remove(pack, context: context, packs: packs, supportRoot: root, defaults: defaults)
    #expect(!packs.contains("hymns-en"))
    #expect(!visibleHymns(in: context, packs: packs).contains { $0.language == "en" })

    let transport = ScriptTransport(pages: [], downloadBody: body)
    let client = PackClient(transport: transport, apiBase: ServiceOrigin.production, token: nil)
    let result = await PackInstaller.install(
        pack,
        client: client,
        context: context,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(result == .installed)
    #expect(packs.contains("hymns-en"))
    #expect(visibleHymns(in: context, packs: packs).contains { $0.id == "test-en-1" })
    #expect(PackFiles.revision(for: "hymns-en", defaults: defaults) != nil)
}

@Test func `a gated pack stays unsigned and unstored while signed out`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let defaults = UserDefaults(suiteName: "pack-gate-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryPackRoot()
    let pack = PackRecord(
        packId: "order-es",
        type: "order",
        language: "es",
        displayName: "Order of Mass · Spanish",
        mode: "download"
    )
    let transport = ScriptTransport(pages: [], downloadStatus: 200, downloadBody: Data("nope".utf8))
    let client = PackClient(transport: transport, apiBase: ServiceOrigin.production, token: nil)
    let result = await PackInstaller.install(
        pack,
        client: client,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(result == .needsSignIn)
    #expect(transport.downloadCount == 0)
    #expect(!FileManager.default.fileExists(atPath: PackFiles.file(for: "order-es", root: root).path))
    #expect(!packs.contains("order-es"))

    let refused = ScriptTransport(pages: [], downloadStatus: 401, downloadBody: Data())
    let open = PackRecord(
        packId: "order-es",
        type: "order",
        language: "es",
        displayName: "Order of Mass · Spanish",
        requiresSignIn: false,
        mode: "download"
    )
    let refusedClient = PackClient(transport: refused, apiBase: ServiceOrigin.production, token: "session")
    let denied = await PackInstaller.install(
        open,
        client: refusedClient,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(denied == .needsSignIn)
    #expect(!FileManager.default.fileExists(atPath: PackFiles.file(for: "order-es", root: root).path))

    let missing = ScriptTransport(pages: [], downloadStatus: 404, downloadBody: Data())
    let missingClient = PackClient(transport: missing, apiBase: ServiceOrigin.production, token: "session")
    let unavailable = await PackInstaller.install(
        open,
        client: missingClient,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(unavailable == .unavailable)
}

@Test func `a static pack replaces the language file the reader loads`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let defaults = UserDefaults(suiteName: "pack-order-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    packs.remove("order-en")
    let root = try temporaryPackRoot()
    let body = Data("""
    {"pack_id":"order-en","type":"order","language":"en","revision":"2026-10-01T12:00:00.000Z","data":[{"order":1,"title":"Test part","items":[{"order":1,"title":"Test item","text":"Test prayer one"}]}]}
    """.utf8)
    let pack = PackRecord(
        packId: "order-en",
        type: "order",
        language: "en",
        displayName: "Order of Mass · English",
        requiresSignIn: false,
        mode: "download"
    )
    let transport = ScriptTransport(pages: [], downloadBody: body)
    let client = PackClient(transport: transport, apiBase: ServiceOrigin.production, token: nil)
    let result = await PackInstaller.install(
        pack,
        client: client,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(result == .installed)
    let loaded = DevotionLibrary.load(.order, language: "en", bundle: Bundle(path: "/usr") ?? .main, supportRoot: root)
    guard case .order(_, let parts) = loaded else {
        Issue.record("The downloaded Order of Mass did not open.")
        return
    }
    #expect(parts.first?.title == "Test part")
    #expect(parts.first?.items.first?.text == "Test prayer one")
    try PackInstaller.remove(pack, context: container.mainContext, packs: packs, supportRoot: root, defaults: defaults)
    #expect(!packs.contains("order-en"))
    #expect(!FileManager.default.fileExists(atPath: PackFiles.file(for: "order-en", root: root).path))
}

private func visibleHymns(in context: ModelContext, packs: InstalledPacks) -> [HymnRecord] {
    let installed = Set(packs.hymnLanguages)
    let hymns = (try? context.fetch(FetchDescriptor<HymnRecord>())) ?? []
    return hymns.filter { installed.contains($0.language) && HymnSearch.matches($0.summary, filter: HymnFilter(text: "test")) }
}

private func temporaryPackRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "packs-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private final class ScriptTransport: PackTransport {
    var pages: [Data]
    var fails: Bool
    var downloadStatus: Int
    var downloadBody: Data
    var downloadCount = 0

    init(pages: [Data], fails: Bool = false, downloadStatus: Int = 200, downloadBody: Data = Data()) {
        self.pages = pages
        self.fails = fails
        self.downloadStatus = downloadStatus
        self.downloadBody = downloadBody
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if fails { throw URLError(.notConnectedToInternet) }
        let url = request.url ?? ServiceOrigin.production
        let downloading = url.path.contains("/download")
        let body: Data
        let status: Int
        if downloading {
            downloadCount += 1
            body = downloadBody
            status = downloadStatus
        } else {
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "page" }?
                .value
            let index = (Int(page ?? "1") ?? 1) - 1
            body = pages.indices.contains(index) ? pages[index] : Data("{\"data\":[],\"page\":1,\"pageSize\":0,\"total\":0}".utf8)
            status = 200
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}
