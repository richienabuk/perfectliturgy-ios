import Foundation
import SwiftData

/// One stored verse. Identity is translation, book, chapter, and verse, so the same verse from two days is one row.
@Model
final class BibleVerseRecord {
    @Attribute(.unique) var id: String
    var translation: String
    var book: String
    var chapter: Int
    var verse: Int
    var text: String

    init(translation: String, book: String, chapter: Int, verse: Int, text: String) {
        self.id = Self.key(translation: translation, book: book, chapter: chapter, verse: verse)
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.text = text
    }

    static func key(translation: String, book: String, chapter: Int, verse: Int) -> String {
        "\(translation)|\(book)|\(chapter)|\(verse)"
    }
}

/// An installed translation and the display window stored with it.
@Model
final class BibleVersionRecord {
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

    var anchor: CivilDate {
        CivilDate(year: anchorYear, month: anchorMonth, day: anchorDay)
    }
}
