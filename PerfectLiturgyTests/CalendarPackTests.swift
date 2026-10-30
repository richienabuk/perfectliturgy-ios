import Foundation
import SwiftData
import Testing
@testable import PerfectLiturgy

@Test func `a valid calendar pack installs and a later pack replaces the file`() async throws {
    let hymns = try HymnStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "calendar-pack-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryCalendarRoot()
    let pack = PackRecord(
        packId: "calendar-test",
        type: "calendar",
        language: "en",
        displayName: "Test calendar",
        requiresSignIn: false,
        mode: "download"
    )
    let first = await PackInstaller.install(
        pack,
        client: PackClient(
            transport: BodyTransport(body: calendarFixture(revision: "rev-1", days: patronDay)),
            apiBase: ServiceOrigin.production,
            token: nil
        ),
        context: hymns.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(first == .installed)
    #expect(packs.contains("calendar-test"))
    #expect(PackFiles.revision(for: "calendar-test", defaults: defaults) == "rev-1")
    let loaded = try CalendarPackReader.decode(Data(contentsOf: PackFiles.file(for: "calendar-test", root: root)))
    #expect(loaded.days.map(\.id) == ["test-patron"])
    #expect(loaded.revision == "rev-1")

    let second = await PackInstaller.install(
        pack,
        client: PackClient(
            transport: BodyTransport(body: calendarFixture(revision: "rev-2", days: """
              {"id":"test-patron","title":"Test patron revised","color":"red","month":10,"day":18}
            """)),
            apiBase: ServiceOrigin.production,
            token: nil
        ),
        context: hymns.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(second == .installed)
    #expect(PackFiles.revision(for: "calendar-test", defaults: defaults) == "rev-2")
    let replaced = try CalendarPackReader.decode(Data(contentsOf: PackFiles.file(for: "calendar-test", root: root)))
    #expect(replaced.days.map(\.title) == ["Test patron revised"])
    #expect(replaced.revision == "rev-2")
}

@Test func `an invalid calendar pack leaves the previous file intact`() async throws {
    let hymns = try HymnStore.make(inMemory: true)
    let defaults = try #require(UserDefaults(suiteName: "calendar-invalid-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryCalendarRoot()
    let pack = PackRecord(
        packId: "calendar-test",
        type: "calendar",
        language: "en",
        displayName: "Test calendar",
        requiresSignIn: false,
        mode: "download"
    )
    let installed = await PackInstaller.install(
        pack,
        client: PackClient(
            transport: BodyTransport(body: calendarFixture(revision: "rev-1", days: patronDay)),
            apiBase: ServiceOrigin.production,
            token: nil
        ),
        context: hymns.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(installed == .installed)

    let failed = await PackInstaller.install(
        pack,
        client: PackClient(
            transport: BodyTransport(body: Data("{\"pack_id\":\"calendar-test\"".utf8)),
            apiBase: ServiceOrigin.production,
            token: nil
        ),
        context: hymns.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(failed == .connection)
    #expect(packs.contains("calendar-test"))
    #expect(PackFiles.revision(for: "calendar-test", defaults: defaults) == "rev-1")
    let kept = try CalendarPackReader.decode(Data(contentsOf: PackFiles.file(for: "calendar-test", root: root)))
    #expect(kept.revision == "rev-1")
    #expect(kept.days.map(\.id) == ["test-patron"])
}

@Test func `a days-only calendar file is rejected and dropped at launch`() throws {
    let defaults = try #require(UserDefaults(suiteName: "calendar-days-only-\(UUID().uuidString)"))
    let packs = InstalledPacks(defaults: defaults)
    let root = try temporaryCalendarRoot()
    packs.install("calendar-legacy")
    PackFiles.storeRevision("rev-1", for: "calendar-legacy", defaults: defaults)
    let legacy = Data("""
    {"pack_id":"calendar-legacy","type":"calendar","revision":"rev-1","data":[
      {"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18}
    ]}
    """.utf8)
    try PackFiles.ensureFolder(root)
    try legacy.write(to: PackFiles.file(for: "calendar-legacy", root: root), options: .atomic)
    #expect(throws: (any Error).self) {
        try CalendarPackReader.decode(legacy)
    }

    CalendarPackReader.reconcileInstalled(packs: packs, defaults: defaults, root: root)
    #expect(!packs.contains("calendar-legacy"))
    #expect(PackFiles.revision(for: "calendar-legacy", defaults: defaults) == nil)
}

@Test func `the first downloaded calendar is selected and remove falls back`() throws {
    let suite = "calendar-auto-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let readings = ReadingsPreferences(defaults: defaults)
    #expect(readings.calendarID == "latin-rite")

    readings.noteCalendarInstalled("calendar-a", installedIDs: ["calendar-a"])
    #expect(readings.calendarID == "calendar-a")

    readings.noteCalendarInstalled("calendar-b", installedIDs: ["calendar-a", "calendar-b"])
    #expect(readings.calendarID == "calendar-a")

    readings.noteCalendarRemoved("calendar-a", remainingIDs: ["calendar-b"])
    #expect(readings.calendarID == "calendar-b")

    readings.noteCalendarRemoved("calendar-b", remainingIDs: [])
    #expect(readings.calendarID == "latin-rite")
}

@Test func `a calendar pack with a bad range is rejected`() {
    let body = calendarFixture(
        revision: "rev-1",
        days: "",
        sunday: """
        {"ot-sunday-1|A":[{"slot":"first","reference":"Test 2:1-5",
          "ranges":[{"book":"ISA","from":"2:5","to":"2:1"}]}]}
        """
    )
    #expect(throws: CalendarPackReader.Failure.badRange) {
        try CalendarPackReader.decode(body)
    }
}

private let patronDay = """
{"id":"test-patron","title":"Test patron","color":"red","month":10,"day":18}
"""

private func calendarFixture(
    packId: String = "calendar-test",
    language: String = "en",
    revision: String,
    days: String,
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

private struct BodyTransport: PackTransport {
    var body: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url ?? ServiceOrigin.production
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private func temporaryCalendarRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "pl-calendar-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
