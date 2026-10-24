import Foundation
import SwiftData
import Testing
@testable import PerfectLiturgy

@Test func `a citation lists each verse and stops when it cannot`() {
    #expect(ScriptureReference.code(for: "Isa") == "isaiah")
    #expect(ScriptureReference.verses(in: "Isaiah 7:14") == [VersePoint(book: "isaiah", chapter: 7, verse: 14)])
    #expect(ScriptureReference.verses(in: "Cf. Mark 9:7") == [VersePoint(book: "mark", chapter: 9, verse: 7)])
    let psalm = ScriptureReference.verses(in: "Psalm 122:1-2, 3-4a, 4b-5, 6-7, 8-9")
    #expect(psalm?.map(\.verse) == [1, 2, 3, 4, 4, 5, 6, 7, 8, 9])
    #expect(ScriptureReference.verses(in: "Isaiah 63:16b-17, 19b; 64:2-7")?.count == 9)
    #expect(ScriptureReference.verses(in: "1 Corinthians 1:3-9")?.count == 7)
    #expect(ScriptureReference.verses(in: "Philemon 9-10, 12-17")?.first?.chapter == 1)
    #expect(ScriptureReference.verses(in: "1 Thessalonians 3:12-4:2") == nil)
    #expect(ScriptureReference.verses(in: "John 18:1-19:42") == nil)
    #expect(ScriptureReference.verses(in: "John 21:1-19 or 21:1-14") == nil)
    #expect(ScriptureReference.verses(in: "Esther C:12, 14-16, 23-25") == nil)
}

@Test func `the display window is a day a week or a month around the anchor`() {
    let anchor = CivilDate(year: 2026, month: 10, day: 18)
    #expect(VerseWindow.contains(anchor, window: "day", anchor: anchor))
    #expect(!VerseWindow.contains(anchor.adding(days: 1), window: "day", anchor: anchor))
    #expect(VerseWindow.contains(CivilDate(year: 2026, month: 10, day: 24), window: "week", anchor: anchor))
    #expect(!VerseWindow.contains(CivilDate(year: 2026, month: 10, day: 25), window: "week", anchor: anchor))
    #expect(VerseWindow.contains(CivilDate(year: 2026, month: 10, day: 31), window: "month", anchor: anchor))
    #expect(!VerseWindow.contains(CivilDate(year: 2026, month: 11, day: 1), window: "month", anchor: anchor))
}

@Test func `an installed translation shows verse text inside the window and stores one row`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let anchor = CivilDate(year: 2026, month: 10, day: 18)
    let pack = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        requiresSignIn: false,
        mode: "live"
    )
    try BibleLibrary.importPack(weekBody, pack: pack, into: context, anchor: anchor)

    #expect(try BibleLibrary.count(translation: "test", in: context) == 9)
    let inside = BiblePassage.text(
        reference: "Isaiah 7:14",
        translation: "test",
        on: anchor,
        window: "week",
        anchor: anchor,
        in: context
    )
    #expect(inside == "Test verse one")
    let laterThatWeek = BiblePassage.text(
        reference: "Matthew 22:15-21",
        translation: "test",
        on: CivilDate(year: 2026, month: 10, day: 19),
        window: "week",
        anchor: anchor,
        in: context
    )
    #expect(laterThatWeek == Array(repeating: "Test verse one", count: 7).joined(separator: " "))
    let incomplete = BiblePassage.text(
        reference: "Isaiah 7:14-16",
        translation: "test",
        on: anchor,
        window: "week",
        anchor: anchor,
        in: context
    )
    #expect(incomplete == nil)
    let outside = BiblePassage.text(
        reference: "Isaiah 7:14",
        translation: "test",
        on: CivilDate(year: 2026, month: 10, day: 25),
        window: "week",
        anchor: anchor,
        in: context
    )
    #expect(outside == nil)

    let dayPack = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        requiresSignIn: false,
        mode: "live",
        metadata: PackMetadata(displayWindow: "day")
    )
    let dayBody = Data("""
    {"data":[
      {"book":"Isa","chapter":7,"verse":14,"text":"Test verse one","date":"2026-10-18"},
      {"book":"Isa","chapter":7,"verse":15,"text":"Test verse two","date":"2026-10-19"}
    ]}
    """.utf8)
    try BibleLibrary.importPack(dayBody, pack: dayPack, into: context, anchor: anchor)
    #expect(try BibleLibrary.count(translation: "test", in: context) == 1)
}

@Test func `installing a readings pack shows today and removing it clears the verses`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let today = CivilDate(Date())
    let iso = String(format: "%04d-%02d-%02d", today.year, today.month, today.day)
    let body = Data("""
    {"pack_id":"readings-test","type":"readings","revision":"1","metadata":{"display_window":"day"},"data":[
      {"book":"Isa","chapter":7,"verse":14,"text":"Test verse one","date":"\(iso)"},
      {"book":"Isa","chapter":7,"verse":15,"text":"Test verse two","date":"\(iso)","deleted_at":"2026-10-01T00:00:00Z"}
    ]}
    """.utf8)
    let defaults = UserDefaults(suiteName: "bible-install-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryBibleRoot()
    let pack = PackRecord(
        packId: "readings-test",
        type: "readings",
        language: "en",
        displayName: "Test version",
        requiresSignIn: false,
        mode: "live",
        metadata: PackMetadata(displayWindow: "week")
    )
    let client = PackClient(transport: BodyTransport(body: body), apiBase: ServiceOrigin.production, token: nil)
    let result = await PackInstaller.install(
        pack,
        client: client,
        context: context,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(result == .installed)
    #expect(try BibleLibrary.count(translation: "test", in: context) == 1)
    let shown = BiblePassage.text(
        reference: "Isaiah 7:14",
        translation: "test",
        on: today,
        window: "day",
        anchor: today,
        in: context
    )
    #expect(shown == "Test verse one")
    let tomorrow = BiblePassage.text(
        reference: "Isaiah 7:14",
        translation: "test",
        on: today.adding(days: 1),
        window: "day",
        anchor: today,
        in: context
    )
    #expect(tomorrow == nil)

    try PackInstaller.remove(pack, context: context, packs: packs, supportRoot: root, defaults: defaults)
    #expect(try BibleLibrary.count(translation: "test", in: context) == 0)
}

@Test func `a country pack changes that date and leaves the next day roman`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let body = Data("""
    {"pack_id":"calendar-test","type":"calendar","revision":"1","data":[
      {"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18},
      {"id":"ascension-transfer","title":"The Ascension of the Lord","color":"white","month":5,"day":17,"year":2026}
    ]}
    """.utf8)
    let wrapped = Data("""
    {"data":{"celebrations":[{"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18}]}}
    """.utf8)
    #expect(CountryCalendar.celebrations(in: wrapped)?.map(\.id) == ["test-patron"])

    let defaults = UserDefaults(suiteName: "calendar-install-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryBibleRoot()
    let pack = PackRecord(
        packId: "calendar-test",
        type: "calendar",
        language: nil,
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
        CountryCalendar.options(ids: packs.ids, catalog: [pack], root: root).first
    )
    #expect(option.title == "Test calendar")

    let sunday = RomanCalendar.day(on: CivilDate(year: 2026, month: 10, day: 18), country: option.celebrations)
    let monday = RomanCalendar.day(on: CivilDate(year: 2026, month: 10, day: 19), country: option.celebrations)
    #expect(sunday.title == "Test patron")
    #expect(sunday.color == .red)
    #expect(sunday.id == "country-test-patron")
    #expect(sunday.fromCountryCalendar == true)
    #expect(sunday.season == .ordinary)
    #expect(monday.title == "Monday of the 29th week in Ordinary Time")
    #expect(monday.fromCountryCalendar == false)
    #expect(monday.id == "ot-feria-29-monday")

    let moved = RomanCalendar.day(on: CivilDate(year: 2026, month: 5, day: 17), country: option.celebrations)
    let kept = RomanCalendar.day(on: CivilDate(year: 2026, month: 5, day: 14), country: option.celebrations)
    #expect(moved.title == "The Ascension of the Lord")
    #expect(kept.title == "The Ascension of the Lord")
    #expect(kept.fromCountryCalendar == false)
}

private let weekBody = Data("""
{"pack_id":"readings-test","type":"readings","metadata":{"display_window":"week"},"data":[
  {"book":"Isa","chapter":7,"verse":14,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Isaiah","chapter":7,"verse":14,"text":"Test verse one","date":"2026-10-19"},
  {"book":"Isa","chapter":7,"verse":15,"text":"Test verse two","date":"2026-10-18"},
  {"book":"Isa","chapter":7,"verse":16,"text":"Test verse three","date":"2026-11-01"},
  {"book":"Matt","chapter":22,"verse":15,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Matt","chapter":22,"verse":16,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Matt","chapter":22,"verse":17,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Matt","chapter":22,"verse":18,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Matt","chapter":22,"verse":19,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Matt","chapter":22,"verse":20,"text":"Test verse one","date":"2026-10-18"},
  {"book":"Matt","chapter":22,"verse":21,"text":"Test verse one","date":"2026-10-19"}
]}
""".utf8)

private struct BodyTransport: PackTransport {
    var body: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url ?? ServiceOrigin.production
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private func temporaryBibleRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "pl-bible-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
