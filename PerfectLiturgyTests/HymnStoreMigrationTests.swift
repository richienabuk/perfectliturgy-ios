import Foundation
import SwiftData
import Testing
@testable import PerfectLiturgy

/// Test-only copies of the Bible models that used to live in the hymns store.
@Model
final class LegacyBibleVerseRecord {
    @Attribute(.unique) var id: String
    var translation: String
    var book: String
    var chapter: Int
    var verse: Int
    var text: String

    init(id: String, translation: String, book: String, chapter: Int, verse: Int, text: String) {
        self.id = id
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.text = text
    }
}

@Model
final class LegacyBibleVersionRecord {
    @Attribute(.unique) var id: String
    var title: String
    var windowRaw: String
    var anchorYear: Int
    var anchorMonth: Int
    var anchorDay: Int

    init(id: String, title: String, windowRaw: String, anchor: CivilDate) {
        self.id = id
        self.title = title
        self.windowRaw = windowRaw
        self.anchorYear = anchor.year
        self.anchorMonth = anchor.month
        self.anchorDay = anchor.day
    }
}

@Test func `a hymns store that held the old Bible models keeps bookmarks hymns and visits`() throws {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "hymns-migrate-\(UUID().uuidString).store")
    let oldSchema = Schema([
        HymnRecord.self,
        HymnSectionRecord.self,
        Bookmark.self,
        HymnVisit.self,
        LegacyBibleVerseRecord.self,
        LegacyBibleVersionRecord.self,
    ])
    let oldConfiguration = ModelConfiguration(schema: oldSchema, url: url, cloudKitDatabase: .none)
    let oldContainer = try ModelContainer(for: oldSchema, configurations: oldConfiguration)
    let oldContext = ModelContext(oldContainer)

    let hymn = HymnRecord(
        id: "test-en-1",
        language: "en",
        hymnNumber: 1,
        title: "Test hymn one",
        firstLine: "Test first line",
        lyrics: "Test lyrics",
        searchKey: "test hymn one"
    )
    oldContext.insert(hymn)
    oldContext.insert(LegacyBibleVerseRecord(
        id: "test|isaiah|7|14",
        translation: "test",
        book: "isaiah",
        chapter: 7,
        verse: 14,
        text: "Test verse one"
    ))
    oldContext.insert(LegacyBibleVersionRecord(
        id: "test",
        title: "Test version",
        windowRaw: "week",
        anchor: CivilDate(year: 2026, month: 10, day: 18)
    ))
    oldContext.insert(
        Bookmark(
            type: BookmarkType.hymns,
            itemId: "test-en-1",
            titleSnapshot: "Test hymn one",
            language: "en",
            createdAt: .now
        )
    )
    oldContext.insert(HymnVisit(hymnId: "test-en-1", openedAt: .now))
    try oldContext.save()

    let migrated = try HymnStore.make(at: url)
    let context = ModelContext(migrated)
    let hymns = try context.fetch(FetchDescriptor<HymnRecord>())
    let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
    let visits = try context.fetch(FetchDescriptor<HymnVisit>())
    #expect(hymns.map(\.id) == ["test-en-1"])
    #expect(hymns.first?.title == "Test hymn one")
    #expect(bookmarks.map(\.itemId) == ["test-en-1"])
    #expect(visits.map(\.hymnId) == ["test-en-1"])
}
