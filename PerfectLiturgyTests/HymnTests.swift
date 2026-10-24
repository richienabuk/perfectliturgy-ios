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
