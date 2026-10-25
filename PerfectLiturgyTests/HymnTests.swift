import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import PerfectLiturgy

@Test func `accent folding strips combining marks`() {
    #expect(AccentFold.fold("Áé") == "ae")
    #expect(AccentFold.fold("e\u{0301}") == "e")
    #expect(AccentFold.fold("Señor") == "senor")
    #expect(HymnSearch.makeKey(title: "Noël", firstLine: "Señor", lyrics: "Test").contains("noel"))
    #expect(HymnSearch.makeKey(title: "Noël", firstLine: "Señor", lyrics: "Test").contains("senor"))
}

@Test func `a refrain with four verses is repeated and the stored order stays`() {
    let sections = [
        HymnSectionText(type: .verse, label: "Stanza", content: "Verse one of the test refrain hymn"),
        HymnSectionText(type: .verse, label: "Stanza", content: "Verse two of the test refrain hymn"),
        HymnSectionText(type: .verse, label: "Stanza", content: "Verse three of the test refrain hymn"),
        HymnSectionText(type: .verse, label: "Stanza", content: "Verse four of the test refrain hymn"),
        HymnSectionText(type: .refrain, label: "Refrain", content: "This is the test refrain"),
    ]
    let blocks = HymnLyrics.blocks(sections: sections, lyrics: "")
    #expect(sections.map(\.type) == [.verse, .verse, .verse, .verse, .refrain])
    #expect(blocks.map(\.heading) == [
        "STANZA 1",
        "STANZA 2",
        "CHORUS / REFRAIN",
        "STANZA 3",
        "STANZA 4",
        "CHORUS / REFRAIN",
    ])
    let share = HymnShareText.make(
        language: "en",
        number: 9004,
        title: "Test refrain hymn",
        seasons: ["lent"],
        massParts: ["offertory"],
        topics: [],
        sections: sections,
        lyrics: "",
        tuneName: nil,
        musicalKey: nil
    )
    #expect(share.components(separatedBy: "CHORUS / REFRAIN").count == 2)

    let short = [
        HymnSectionText(type: .verse, label: "", content: "One"),
        HymnSectionText(type: .verse, label: "", content: "Two"),
        HymnSectionText(type: .refrain, label: "", content: "Hold"),
    ]
    #expect(HymnLyrics.blocks(sections: short, lyrics: "").filter { $0.card == .refrain }.count == 1)
    #expect(HymnLyrics.blocks(sections: [], lyrics: "Test hymn lyrics with no sections").map(\.heading) == ["STANZA 1"])
}

@Test func `a second import does not add copies`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let bundle = Bundle(for: DesignPreferences.self)
    let english = try #require(HymnBundles.url(for: "hymns_en", in: bundle))
    let data = try Data(contentsOf: english)
    try HymnImporter.importData(data, into: context)
    let first = try context.fetch(FetchDescriptor<HymnRecord>())
    try HymnImporter.importData(data, into: context)
    let second = try context.fetch(FetchDescriptor<HymnRecord>())
    #expect(first.count == second.count)
    #expect(second.count == 7)
    let refrain = try #require(second.first { $0.id == "test-en-4" })
    #expect(refrain.sections.count == 5)
    #expect(refrain.orderedSections.map(\.typeRaw) == ["verse", "verse", "verse", "verse", "refrain"])
}

@Test func `searching test finds fixture hymns`() throws {
    let loaded = try importedFixtures()
    defer { _ = loaded.0 }
    let hymns = loaded.1
    let found = hymns.filter { HymnSearch.matches($0.summary, filter: HymnFilter(text: "test")) }
    #expect(found.contains { $0.id == "test-en-1" })
    #expect(found.contains { $0.id == "test-la-1" })
    #expect(found.count == hymns.count)

    let folded = hymns.filter { HymnSearch.matches($0.summary, filter: HymnFilter(text: "noel")) }
    #expect(folded.map(\.id) == ["test-en-3"])

    let byNumber = hymns.filter { HymnSearch.matches($0.summary, filter: HymnFilter(text: "9004")) }
    #expect(byNumber.map(\.id) == ["test-en-4"])

    let byID = hymns.filter { HymnSearch.matches($0.summary, filter: HymnFilter(text: "test-la-2")) }
    #expect(byID.map(\.id) == ["test-la-2"])
}

private let stanzaHymn = Data("""
[{
  "id": "test-en-stanza",
  "language": "en",
  "hymnNumber": 9100,
  "title": "Test stanza hymn",
  "lyrics": "Opening line only",
  "sections": [
    {"type": "verse", "content": "Opening line only"},
    {"type": "verse", "content": "Zebra crossing in Noël"}
  ]
}]
""".utf8)

@Test func `a word that is only in a later stanza is found`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    try HymnImporter.importData(stanzaHymn, into: context)
    let hymn = try #require(try context.fetch(FetchDescriptor<HymnRecord>()).first)
    let summary = hymn.summary

    #expect(HymnSearch.matches(summary, filter: HymnFilter(text: "zebra")))
    #expect(HymnSearch.matches(summary, filter: HymnFilter(text: "ZEBRA noel")))
    #expect(!HymnSearch.matches(summary, filter: HymnFilter(text: "yak")))

    // A query folded once gives the same answer as one folded per hymn.
    let query = HymnQuery("zebra noel")
    #expect(HymnSearch.matches(summary, filter: HymnFilter(), query: query))
    #expect(query.words == ["zebra", "noel"])
}

@Test func `the search key does not repeat lyrics that come from the sections`() throws {
    let lyrics = "One\nTwo"
    let derived = HymnSearch.makeKey(title: "T", firstLine: "One", lyrics: lyrics, sections: ["One", "Two"])
    let plain = HymnSearch.makeKey(title: "T", firstLine: "One", lyrics: lyrics)
    #expect(derived == plain)
}

@Test func `an old search key is rebuilt once from the stored sections`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    try HymnImporter.importData(stanzaHymn, into: context)
    let hymn = try #require(try context.fetch(FetchDescriptor<HymnRecord>()).first)
    hymn.searchKey = "test stanza hymn opening line only"
    #expect(!HymnSearch.matches(hymn.summary, filter: HymnFilter(text: "zebra")))

    let defaults = UserDefaults(suiteName: "search-key-\(UUID().uuidString)")!
    try HymnImporter.rebuildSearchKeysIfNeeded(in: context, defaults: defaults)
    #expect(HymnSearch.matches(hymn.summary, filter: HymnFilter(text: "zebra")))
    #expect(defaults.integer(forKey: "hymns.searchKeyVersion") == HymnImporter.searchKeyVersion)

    // Once the version is stored, a changed key is left alone.
    hymn.searchKey = "changed"
    try HymnImporter.rebuildSearchKeysIfNeeded(in: context, defaults: defaults)
    #expect(hymn.searchKey == "changed")
}

@Test @MainActor func `the catalogue reader returns the list in order from a background context`() async throws {
    let loaded = try importedFixtures()
    let container = loaded.0
    let expected = loaded.1
        .sorted { ($0.language, $0.hymnNumber) < ($1.language, $1.hymnNumber) }
        .map(\.summary)

    let summaries = await HymnCatalogueReader.load(from: container)
    #expect(summaries == expected)
    #expect(!summaries.isEmpty)
}

@Test @MainActor func `the list loads once and a later load replaces it`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let model = HymnListModel()
    let inputs = HymnListModel.Inputs(installed: ["en"])
    #expect(!model.isLoaded)

    await model.load(from: container) { inputs }
    #expect(model.isLoaded)
    #expect(model.filtered.isEmpty)

    try HymnImporter.importData(stanzaHymn, into: context)
    await model.load(from: container) { inputs }
    #expect(model.filtered.map(\.id) == ["test-en-stanza"])
    #expect(model.rows.map(\.id) == ["test-en-stanza"])
}

@Test @MainActor func `the pack catalog store reads the saved list once and again after it is saved`() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("hymn-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = PackCatalogStore(root: root)
    await store.reload()
    // No saved list yet: the seeded rows stay.
    #expect(store.packs.map(\.packId) == PackSeed.rows.map(\.packId))

    try PackFiles.saveCatalog(
        [
            PackRecord(packId: "hymns-efi", type: "hymns", language: "efi", languageName: "Efik", displayName: "Efik Hymns", mode: "download"),
            PackRecord(packId: "prayers-en", type: "prayers", language: "en", displayName: "Prayers", mode: "download"),
        ],
        root: root
    )
    await store.reload()
    // The saved rows lead. A seeded row the server leaves out stays, so its language keeps its name.
    #expect(store.packs(ofType: "hymns").map(\.packId) == ["hymns-efi", "hymns-en", "hymns-la"])
    #expect(store.packs(ofType: "prayers").map(\.packId) == ["prayers-en", "prayers-la"])
    #expect(HymnLanguage.name(for: "efi", in: store.packs) == "Efik")
    #expect(HymnLanguage.name(for: "la", in: store.packs) == "Latin")
}

@Test func `a season and a mass part together return only hymns with both`() throws {
    let loaded = try importedFixtures()
    defer { _ = loaded.0 }
    let hymns = loaded.1
    let adventEntrance = hymns.filter {
        HymnSearch.matches($0.summary, filter: HymnFilter(season: "advent", massPart: "entrance"))
    }
    #expect(adventEntrance.map(\.id) == ["test-en-1"])

    let advent = hymns.filter {
        HymnSearch.matches($0.summary, filter: HymnFilter(season: "advent"))
    }
    #expect(Set(advent.map(\.id)) == ["test-en-1", "test-en-2"])

    let easterOffertory = hymns.filter {
        HymnSearch.matches($0.summary, filter: HymnFilter(season: "easter", massPart: "offertory"))
    }
    #expect(easterOffertory.map(\.id) == ["test-en-6"])

    let english = hymns.filter {
        HymnSearch.matches($0.summary, filter: HymnFilter(text: "test", language: "en"))
    }
    #expect(english.allSatisfy { $0.language == "en" })
    #expect(english.count == 7)
}

@Test func `a changed hymn id keeps the bookmark`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let first = Data("""
    [{"id":"test-old","language":"en","hymn_number":42,"title":"Test hymn one","sections":[{"type":"verse","content":"Test line"}]}]
    """.utf8)
    let second = Data("""
    [{"id":"test-new","language":"en","hymn_number":42,"title":"Test hymn one","sections":[{"type":"verse","content":"Test line"}]}]
    """.utf8)
    try HymnImporter.importData(first, into: context)
    let hymn = try #require(try context.fetch(FetchDescriptor<HymnRecord>()).first)
    try HymnImporter.toggleBookmark(hymn, in: context)
    try HymnImporter.importData(second, into: context)
    let bookmarks = try context.fetch(FetchDescriptor<HymnBookmark>())
    #expect(bookmarks.map(\.hymnId) == ["test-new"])
    #expect(try context.fetch(FetchDescriptor<HymnRecord>()).count == 1)
}

@Test func `visits keep the newest eight`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    for index in 0..<10 {
        try HymnImporter.recordVisit(hymnID: "visit-\(index)", in: context)
    }
    let visits = try context.fetch(FetchDescriptor<HymnVisit>())
    #expect(visits.count == 8)
    #expect(!visits.contains { $0.hymnId == "visit-0" })
    #expect(visits.contains { $0.hymnId == "visit-9" })
}

@Test func `video links embed youtube and vimeo`() throws {
    let youtube = try #require(URL(string: "https://www.youtube.com/watch?v=testvideo"))
    #expect(HymnVideo.youtubeID(from: youtube) == "testvideo")
    let vimeo = try #require(URL(string: "https://vimeo.com/99"))
    #expect(HymnVideo.embedURL(for: vimeo)?.absoluteString == "https://player.vimeo.com/video/99")
    let other = try #require(URL(string: "https://example.com/test-video"))
    #expect(HymnVideo.embedURL(for: other) == nil)
}

@Test func `a second bundled import leaves the fixture count unchanged`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let defaults = UserDefaults(suiteName: "hymns-\(UUID().uuidString)")!
    let bundle = Bundle(for: DesignPreferences.self)
    try HymnImporter.importBundledIfNeeded(into: context, bundle: bundle, defaults: defaults)
    let first = try context.fetchCount(FetchDescriptor<HymnRecord>())
    try HymnImporter.importBundledIfNeeded(into: context, bundle: bundle, defaults: defaults)
    let second = try context.fetchCount(FetchDescriptor<HymnRecord>())
    #expect(first == second)
    if HymnBundles.url(for: "hymns_en_catalogue", in: bundle) != nil {
        #expect(first > 300)
    }
    let titles = try context.fetch(FetchDescriptor<HymnRecord>()).filter { $0.title == "Test hymn one" }
    #expect(titles.isEmpty)
}

@Test func renderHymnScreens() async throws {
    let loaded = try importedFixtures()
    defer { _ = loaded.0 }
    let navigation = AppNavigation()
    let design = DesignPreferences()
    let packs = InstalledPacks(defaults: UserDefaults(suiteName: "render-hymns-\(UUID().uuidString)")!)
    let list = HymnsView(initialQuery: "test")
        .modelContainer(loaded.0)
        .environment(navigation)
        .environment(design)
        .environment(packs)
        .environment(LanguageSelection(defaults: UserDefaults(suiteName: "render-language-\(UUID().uuidString)")!))
        .environment(\.readingScale, design.readingScale)
        .resolvePalette()
        .frame(width: 390, height: 844)
    let listImage = try await snapshot(list, size: CGSize(width: 390, height: 844))
    Attachment.record(listImage, named: "hymn-list")

    let detail = HymnDetailView(id: "test-en-4")
        .modelContainer(loaded.0)
        .environment(navigation)
        .environment(design)
        .environment(\.readingScale, design.readingScale)
        .resolvePalette()
        .frame(width: 390, height: 1600)
    let detailImage = try await snapshot(detail, size: CGSize(width: 390, height: 1600))
    Attachment.record(detailImage, named: "hymn-detail")
    #expect(listImage.size.width > 300)
    #expect(detailImage.size.height > 1000)

    navigation.tab = .hymns
    let wide = RootView()
        .modelContainer(loaded.0)
        .environment(navigation)
        .environment(design)
        .environment(packs)
        .environment(LanguageSelection(defaults: UserDefaults(suiteName: "render-language-\(UUID().uuidString)")!))
        .environment(\.readingScale, design.readingScale)
        .environment(\.isWideLayout, true)
        .resolvePalette()
        .frame(width: 1180, height: 820)
    let wideImage = try await snapshot(wide, size: CGSize(width: 1180, height: 820))
    Attachment.record(wideImage, named: "hymn-wide")
    #expect(wideImage.size.width > 1000)
}

@Test @MainActor func removingEveryHymnLeavesTheList() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let bundle = Bundle(for: DesignPreferences.self)
    for name in ["hymns_en", "hymns_la", "hymns_en_catalogue", "hymns_la_catalogue"] {
        guard let url = HymnBundles.url(for: name, in: bundle) else { continue }
        try HymnImporter.importData(try Data(contentsOf: url), into: context)
    }
    let hymnID = try #require(context.fetch(FetchDescriptor<HymnRecord>()).first?.id)
    let defaults = UserDefaults(suiteName: "empty-hymns-\(UUID().uuidString)")!
    defaults.set(["hymns-en", "hymns-la"], forKey: InstalledPacks.storageKey)
    let packs = InstalledPacks(defaults: defaults)
    let navigation = AppNavigation()
    let design = DesignPreferences()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("empty-hymns-\(UUID().uuidString)", isDirectory: true)
    let view = VStack {
        HymnsView()
        HymnDetailView(id: hymnID)
    }
        .modelContainer(container)
        .environment(navigation)
        .environment(design)
        .environment(packs)
        .environment(LanguageSelection(defaults: UserDefaults(suiteName: "render-language-\(UUID().uuidString)")!))
        .environment(\.readingScale, design.readingScale)
        .resolvePalette()
        .frame(width: 390, height: 844)
    let host = UIHostingController(rootView: view)
    let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
    host.view.bounds = bounds
    host.view.frame = bounds
    let window = UIWindow(frame: bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(400))
    for code in ["en", "la"] {
        let pack = PackRecord(
            packId: "hymns-\(code)",
            type: "hymns",
            language: code,
            displayName: code,
            mode: "download"
        )
        try PackInstaller.remove(
            pack,
            context: context,
            packs: packs,
            supportRoot: root,
            defaults: defaults
        )
    }
    try await Task.sleep(for: .milliseconds(400))
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    #expect(try context.fetchCount(FetchDescriptor<HymnRecord>()) == 0)
    #expect(packs.hymnLanguages.isEmpty)
}

@MainActor
private func snapshot<V: View>(_ view: V, size: CGSize) async throws -> UIImage {
    let host = UIHostingController(rootView: view)
    let bounds = CGRect(origin: .zero, size: size)
    host.view.bounds = bounds
    host.view.frame = bounds
    let window = UIWindow(frame: bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(400))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    return UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
        host.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
    }
}

private func importedFixtures() throws -> (ModelContainer, [HymnRecord]) {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let bundle = Bundle(for: DesignPreferences.self)
    for name in ["hymns_en", "hymns_la"] {
        let url = try #require(HymnBundles.url(for: name, in: bundle))
        try HymnImporter.importData(try Data(contentsOf: url), into: context)
    }
    let hymns = try context.fetch(FetchDescriptor<HymnRecord>(sortBy: [SortDescriptor(\.hymnNumber)]))
    return (container, hymns)
}

@Test func `a fitted sheet remembers its height`() {
    let key = "test.\(UUID().uuidString)"
    defer { UserDefaults.standard.removeObject(forKey: "sheetHeight.\(key)") }
    #expect(SheetHeights.remembered(key) == nil)
    SheetHeights.remember(312.5, for: key)
    #expect(SheetHeights.remembered(key) == 312.5)
}

@Test @MainActor func `refiltering the bundled catalogues stays fast`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let bundle = Bundle(for: DesignPreferences.self)
    for name in HymnBundles.resourceNames {
        let url = try #require(HymnBundles.url(for: name, in: bundle))
        try HymnImporter.importData(try Data(contentsOf: url), into: context)
    }
    let summaries = await HymnCatalogueReader.load(from: container)
    #expect(summaries.count > 300)

    let model = HymnListModel()
    var inputs = HymnListModel.Inputs(installed: ["en", "la"], catalogues: PackSeed.rows.filter { $0.type == "hymns" })
    model.setCatalogue(summaries, inputs: inputs)

    // Typing, a language change, and a season change, over and over.
    let queries = ["", "l", "lo", "lord", "lord of", "gloria", "adeste", "ave maria"]
    let clock = ContinuousClock()
    let runs = 100
    let elapsed = clock.measure {
        for index in 0..<runs {
            inputs.query = queries[index % queries.count]
            inputs.language = index % 3 == 0 ? "en" : nil
            inputs.season = index % 5 == 0 ? "advent" : nil
            model.refilter(inputs, force: true)
        }
    }
    let average = elapsed / runs
    // A Debug build on a simulator is several times slower than Release on a device.
    #if DEBUG
    let limit = Duration.milliseconds(25)
    #else
    let limit = Duration.milliseconds(5)
    #endif
    #expect(average < limit, "average refilter \(average)")
}
