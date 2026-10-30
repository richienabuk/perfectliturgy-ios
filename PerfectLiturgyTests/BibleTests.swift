import Foundation
import SwiftData
import Testing
@testable import PerfectLiturgy

@Test func `the Bible store opens, reads a range, and a forced reset clears readings installs`() throws {
    let suite = "bible-store-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let packs = InstalledPacks(defaults: defaults)
    packs.install("readings-test")
    PackFiles.storeRevision("rev-1", for: "readings-test", defaults: defaults)

    let container = try BibleStore.make(inMemory: true)
    let context = ModelContext(container)
    context.insert(
        BibleVerse(
            versionID: "test",
            bookID: "ISA",
            chapter: 7,
            verse: 14,
            text: "Test verse one"
        )
    )
    context.insert(
        BibleVerse(
            versionID: "test",
            bookID: "ISA",
            chapter: 7,
            verse: 15,
            text: "Test verse two"
        )
    )
    try context.save()

    let range = try BibleStore.verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 15,
        in: context
    )
    #expect(range.map(\.text) == ["Test verse one", "Test verse two"])
    #expect(BibleStore.verseCount(versionID: "test", in: context) == 2)

    BibleStore.resetForcingClear(defaults: defaults)
    let cleared = InstalledPacks(defaults: defaults)
    #expect(!cleared.contains("readings-test"))
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == nil)
}

@Test func `launch reconciliation drops a readings pack that has no verses`() throws {
    let suite = "bible-reconcile-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let packs = InstalledPacks(defaults: defaults)
    packs.install("readings-empty")
    PackFiles.storeRevision("rev-1", for: "readings-empty", defaults: defaults)
    let container = try BibleStore.make(inMemory: true)
    BibleStore.reconcileInstalled(packs: packs, defaults: defaults, container: container)
    #expect(!packs.contains("readings-empty"))
    #expect(PackFiles.revision(for: "readings-empty", defaults: defaults) == nil)
}

@Test func `a range read on a full-size fixture stays under budget`() throws {
    let container = try BibleStore.make(inMemory: true)
    let context = ModelContext(container)
    let versions = ["a", "b"]
    let books = ["GEN", "PSA", "ISA", "MAT", "EPH"]
    var inserted = 0
    for version in versions {
        for book in books {
            for chapter in 1...35 {
                for verse in 1...100 {
                    context.insert(
                        BibleVerse(
                            versionID: version,
                            bookID: book,
                            chapter: chapter,
                            verse: verse,
                            text: "Test \(version) \(book) \(chapter):\(verse)"
                        )
                    )
                    inserted += 1
                }
            }
        }
    }
    try context.save()
    #expect(inserted == 35_000)

    let started = ContinuousClock.now
    let rows = try BibleStore.verses(
        versionID: "a",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 1,
        toChapter: 7,
        toVerse: 100,
        in: context
    )
    let elapsed = ContinuousClock.now - started
    #expect(rows.count == 100)
    #expect(elapsed < .milliseconds(100))
}

@Test func `installing a readings pack stores verses with segments and removing it clears them`() async throws {
    let container = try BibleStore.make(inMemory: true)
    let hymnContainer = try HymnStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "bible-install-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryBibleRoot()
    let pack = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        requiresSignIn: false,
        mode: "live"
    )
    let client = PackClient(
        transport: BodyTransport(body: readingsPack(revision: "rev-1", verses: [
            readingsVerse(book: "ISA", chapter: 7, verse: 14, text: "Test narration. Test quoted words.", segments: true),
            readingsVerse(book: "ISA", chapter: 7, verse: 15, text: "Test verse two"),
        ])),
        apiBase: ServiceOrigin.production,
        token: nil
    )
    let result = await PackInstaller.install(
        pack,
        client: client,
        context: hymnContainer.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: container
    )
    #expect(result == .installed)
    #expect(packs.contains("readings-test"))
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == "rev-1")

    let reader = BibleReader(modelContainer: container)
    let rows = try await reader.verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 15
    )
    #expect(rows.count == 2)
    #expect(rows[0].segmentsJSON?.contains("quote") == true)
    let available = try await reader.isAvailable(
        versionID: "test",
        ranges: [VerseRange(book: "ISA", from: "7:14", to: "7:15", continues: false)]
    )
    #expect(available)

    try await PackInstaller.remove(
        pack,
        context: hymnContainer.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: container
    )
    let after = try await reader.verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 15
    )
    #expect(after.isEmpty)
    #expect(!packs.contains("readings-test"))
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == nil)
}

@Test func `a sync page tombstones a verse and a later page changes another`() async throws {
    let container = try BibleStore.make(inMemory: true)
    let importer = BibleImporter(modelContainer: container)
    let reader = BibleReader(modelContainer: container)
    let seed = try BiblePackReader.decode(readingsPack(revision: "rev-1", verses: [
        readingsVerse(book: "ISA", chapter: 7, verse: 14, text: "Test narration. Test quoted words.", segments: true),
        readingsVerse(book: "ISA", chapter: 7, verse: 15, text: "Test verse two"),
        readingsVerse(book: "EPH", chapter: 4, verse: 32, text: "Test verse three"),
    ]))
    try await importer.replaceVersion(payload: seed, displayName: "Test version")

    let page = try BiblePackReader.decode(readingsPack(
        revision: "rev-2",
        verses: [
            readingsVerse(book: "ISA", chapter: 7, verse: 15, text: "", deleted: true),
            readingsVerse(book: "EPH", chapter: 4, verse: 32, text: "Test verse three revised"),
        ],
        includeBooks: false
    ))
    try await importer.applyPage(payload: page, displayName: "Test version")

    let isa = try await reader.verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 15
    )
    #expect(isa.map(\.text) == ["Test narration. Test quoted words."])
    let eph = try await reader.verses(
        versionID: "test",
        bookID: "EPH",
        fromChapter: 4,
        fromVerse: 32,
        toChapter: 4,
        toVerse: 32
    )
    #expect(eph.map(\.text) == ["Test verse three revised"])
}

@Test func `an interrupted readings sync keeps the old revision and a re-run finishes`() async throws {
    let bible = try BibleStore.make(inMemory: true)
    let hymns = try HymnStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "bible-sync-interrupt-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    packs.install("readings-test")
    PackFiles.storeRevision("rev-1", for: "readings-test", defaults: defaults)
    let pack = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        revision: "rev-3",
        requiresSignIn: true,
        mode: "live"
    )
    let seed = try BiblePackReader.decode(readingsPack(revision: "rev-1", verses: [
        readingsVerse(book: "ISA", chapter: 7, verse: 14, text: "Test narration."),
    ]))
    try await BibleImporter(modelContainer: bible).replaceVersion(payload: seed, displayName: pack.displayName)

    let page1 = readingsPack(
        revision: "rev-3",
        verses: [readingsVerse(book: "ISA", chapter: 7, verse: 14, text: "Test narration revised.")],
        includeBooks: false,
        nextCursor: "cursor-2"
    )
    let broken = SyncPageTransport(pages: [page1, Data("not-json".utf8)])
    let failed = await ContentSync.run(
        installed: ["readings-test"],
        catalog: [pack],
        client: PackClient(transport: broken, apiBase: URL(string: "https://api.example.test")!, token: "session-1"),
        context: hymns.mainContext,
        packs: packs,
        supportRoot: try temporaryBibleRoot(),
        defaults: defaults,
        bibleContainer: bible,
        mergeBookmarks: {}
    )
    #expect(failed.outcome == .connection)
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == "rev-1")
    #expect(broken.requests.count == 2)
    #expect(cursor(broken.requests[0]) == nil)
    #expect(cursor(broken.requests[1]) == "cursor-2")

    let page2 = readingsPack(
        revision: "rev-3",
        verses: [readingsVerse(book: "EPH", chapter: 4, verse: 32, text: "Test verse three")],
        includeBooks: false
    )
    let complete = SyncPageTransport(pages: [page1, page2])
    let finished = await ContentSync.run(
        installed: ["readings-test"],
        catalog: [pack],
        client: PackClient(transport: complete, apiBase: URL(string: "https://api.example.test")!, token: "session-1"),
        context: hymns.mainContext,
        packs: packs,
        supportRoot: try temporaryBibleRoot(),
        defaults: defaults,
        bibleContainer: bible,
        mergeBookmarks: {}
    )
    #expect(finished.outcome == .current)
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == "rev-3")
    let reader = BibleReader(modelContainer: bible)
    let rows = try await reader.verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 14
    )
    #expect(rows.map(\.text) == ["Test narration revised."])
    let eph = try await reader.verses(
        versionID: "test",
        bookID: "EPH",
        fromChapter: 4,
        fromVerse: 32,
        toChapter: 4,
        toVerse: 32
    )
    #expect(eph.map(\.text) == ["Test verse three"])
}

@Test func `a second container on the same file keeps installed verses`() async throws {
    let folder = FileManager.default.temporaryDirectory
        .appending(path: "bible-relaunch-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let storeURL = folder.appending(path: "bible.store")
    let payload = try BiblePackReader.decode(readingsPack(revision: "rev-1", verses: [
        readingsVerse(book: "ISA", chapter: 7, verse: 14, text: "Test narration."),
    ]))
    do {
        let first = try BibleStore.make(at: storeURL)
        try await BibleImporter(modelContainer: first).replaceVersion(payload: payload, displayName: "Test version")
    }

    let second = try BibleStore.make(at: storeURL)
    let rows = try await BibleReader(modelContainer: second).verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 14
    )
    #expect(rows.map(\.text) == ["Test narration."])
}

@Test func `a failed readings download leaves the previous Bible intact`() async throws {
    let container = try BibleStore.make(inMemory: true)
    let hymns = try HymnStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "bible-failed-download-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryBibleRoot()
    let pack = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        requiresSignIn: false,
        mode: "live"
    )
    let good = PackClient(
        transport: BodyTransport(body: readingsPack(revision: "rev-1", verses: [
            readingsVerse(book: "ISA", chapter: 7, verse: 14, text: "Test narration."),
        ])),
        apiBase: ServiceOrigin.production,
        token: nil
    )
    let installed = await PackInstaller.install(
        pack,
        client: good,
        context: hymns.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: container
    )
    #expect(installed == .installed)

    let bad = PackClient(
        transport: BodyTransport(body: Data("{\"pack_id\":\"readings-test\"".utf8)),
        apiBase: ServiceOrigin.production,
        token: nil
    )
    let failed = await PackInstaller.install(
        pack,
        client: bad,
        context: hymns.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults,
        bibleContainer: container
    )
    #expect(failed == .connection)
    #expect(packs.contains("readings-test"))
    #expect(PackFiles.revision(for: "readings-test", defaults: defaults) == "rev-1")
    let rows = try await BibleReader(modelContainer: container).verses(
        versionID: "test",
        bookID: "ISA",
        fromChapter: 7,
        fromVerse: 14,
        toChapter: 7,
        toVerse: 14
    )
    #expect(rows.map(\.text) == ["Test narration."])
}

@Test func `a calendar pack changes that date and leaves the next day on the Latin Rite`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let body = calendarPackBody(days: """
      {"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18},
      {"id":"ascension-transfer","title":"The Ascension of the Lord","color":"white","month":5,"day":17,"year":2026}
    """)
    #expect(throws: (any Error).self) {
        try CalendarPackReader.decode(Data("""
        {"pack_id":"calendar-test","type":"calendar","revision":"1","data":[
          {"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18}
        ]}
        """.utf8))
    }

    let defaults = UserDefaults(suiteName: "calendar-install-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryBibleRoot()
    let pack = PackRecord(
        packId: "calendar-test",
        type: "calendar",
        language: "en",
        displayName: "Test calendar",
        requiresSignIn: false,
        mode: "download"
    )
    let client = PackClient(transport: BodyTransport(body: body), apiBase: ServiceOrigin.production, token: nil)
    let result = await PackInstaller.install(
        pack,
        client: client,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(result == .installed)
    let option = try #require(
        CalendarPackReader.installed(ids: packs.ids, catalog: [pack], root: root).first
    )
    #expect(option.title == "Test calendar")
    #expect(option.language == "en")

    let sunday = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 10, day: 18), country: option.celebrations)
    let monday = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 10, day: 19), country: option.celebrations)
    #expect(sunday.title == "Test patron")
    #expect(sunday.color == .red)
    #expect(sunday.id == "country-test-patron")
    #expect(sunday.fromCountryCalendar == true)
    #expect(sunday.season == .ordinary)
    #expect(monday.title == "Monday of the 29th week in Ordinary Time")
    #expect(monday.fromCountryCalendar == false)
    #expect(monday.id == "ot-feria-29-monday")

    let moved = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 5, day: 17), country: option.celebrations)
    let kept = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 5, day: 14), country: option.celebrations)
    #expect(moved.title == "The Ascension of the Lord")
    #expect(kept.title == "The Ascension of the Lord")
    #expect(kept.fromCountryCalendar == false)
}

private struct BodyTransport: PackTransport {
    var body: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url ?? ServiceOrigin.production
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private final class SyncPageTransport: PackTransport {
    var pages: [Data]
    var requests: [URLRequest] = []

    init(pages: [Data]) {
        self.pages = pages
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let body = pages.isEmpty ? Data() : pages.removeFirst()
        let url = request.url ?? URL(string: "https://api.example.test")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private func temporaryBibleRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "pl-bible-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func calendarPackBody(
    packId: String = "calendar-test",
    language: String = "en",
    revision: String = "1",
    days: String = "",
    sunday: String = "{}",
    feria: String = "{}",
    proper: String = "{}"
) -> Data {
    Data("""
    {"pack_id":"\(packId)","type":"calendar","language":"\(language)","revision":"\(revision)",
     "display_name":"Test calendar","metadata":{"region":"test"},
     "data":{"days":[\(days)],"formulas":{},"sunday":\(sunday),"feria":\(feria),"proper":\(proper)}}
    """.utf8)
}

private func cursor(_ request: URLRequest) -> String? {
    URLComponents(url: request.url ?? URL(string: "https://api.example.test")!, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first { $0.name == "cursor" }?
        .value
}

private func readingsVerse(
    book: String,
    chapter: Int,
    verse: Int,
    text: String,
    segments: Bool = false,
    deleted: Bool = false
) -> String {
    let segmentJSON = segments
        ? #","segments":[{"t":"Test narration.","part":"a"},{"t":" Test quoted words.","part":"b","style":"quote"}]"#
        : ""
    let deletedJSON = deleted ? #""deleted_at":"2026-10-20T12:00:00Z""# : #""deleted_at":null"#
    return """
    {"book":"\(book)","chapter":\(chapter),"verse":\(verse),"text":"\(text)"\(segmentJSON),\
    "updated_at":"2026-10-19T12:00:00Z",\(deletedJSON)}
    """
}

private func readingsPack(
    revision: String,
    verses: [String],
    includeBooks: Bool = true,
    nextCursor: String? = nil
) -> Data {
    let books = includeBooks
        ? #""books":[{"id":"ISA","order":23,"name":"Isaiah","abbr":"Isa"},{"id":"EPH","order":49,"name":"Ephesians","abbr":"Eph"}],"#
        : ""
    let cursor: String
    if let nextCursor {
        cursor = ",\"next_cursor\":\"\(nextCursor)\""
    } else {
        cursor = ""
    }
    return Data("""
    {"pack_id":"readings-test","type":"readings","language":"en","revision":"\(revision)",
     "metadata":{"versification":"lectionary","coverage_through":"2026-12-31"},
     \(books)
     "data":[\(verses.joined(separator: ","))]\(cursor)}
    """.utf8)
}
