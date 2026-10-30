import Foundation
import SwiftData

/// An installed Bible version. The id is the pack id without the `readings-` prefix.
@Model
final class BibleVersion {
    @Attribute(.unique) var id: String
    var packId: String
    var language: String
    var displayName: String
    var abbr: String
    var revision: String
    var versification: String
    var coverageThrough: String?
    var installedAt: Date

    init(
        id: String,
        packId: String,
        language: String,
        displayName: String,
        abbr: String,
        revision: String,
        versification: String,
        coverageThrough: String? = nil,
        installedAt: Date = .now
    ) {
        self.id = id
        self.packId = packId
        self.language = language
        self.displayName = displayName
        self.abbr = abbr
        self.revision = revision
        self.versification = versification
        self.coverageThrough = coverageThrough
        self.installedAt = installedAt
    }
}

/// One book name in one Bible version. Key is `version|book`.
@Model
final class BibleBook {
    @Attribute(.unique) var key: String
    var versionID: String
    var bookID: String
    var order: Int
    var name: String
    var abbr: String

    init(versionID: String, bookID: String, order: Int, name: String, abbr: String) {
        self.key = Self.key(versionID: versionID, bookID: bookID)
        self.versionID = versionID
        self.bookID = bookID
        self.order = order
        self.name = name
        self.abbr = abbr
    }

    static func key(versionID: String, bookID: String) -> String {
        "\(versionID)|\(bookID)"
    }
}

/// One verse in one Bible version. Key is `version|book|` + `pos` zero-padded to six digits.
@Model
final class BibleVerse {
    @Attribute(.unique) var key: String
    var versionID: String
    var bookID: String
    var pos: Int
    var chapter: Int
    var verse: Int
    var text: String
    var segmentsJSON: String?
    var updatedAt: Date

    init(
        versionID: String,
        bookID: String,
        chapter: Int,
        verse: Int,
        text: String,
        segmentsJSON: String? = nil,
        updatedAt: Date = .now
    ) {
        let pos = Self.pos(chapter: chapter, verse: verse)
        self.key = Self.key(versionID: versionID, bookID: bookID, pos: pos)
        self.versionID = versionID
        self.bookID = bookID
        self.pos = pos
        self.chapter = chapter
        self.verse = verse
        self.text = text
        self.segmentsJSON = segmentsJSON
        self.updatedAt = updatedAt
    }

    static func pos(chapter: Int, verse: Int) -> Int {
        chapter * 1000 + verse
    }

    static func key(versionID: String, bookID: String, pos: Int) -> String {
        String(format: "%@|%@|%06d", versionID, bookID, pos)
    }
}

/// A verse returned from a range read. Never a model object.
nonisolated struct StoredVerse: Equatable, Sendable {
    var chapter: Int
    var verse: Int
    var text: String
    var segmentsJSON: String?
}
