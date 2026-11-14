import Foundation
import SwiftData

@Model
nonisolated final class HymnRecord {
    @Attribute(.unique) var id: String
    var language: String
    var hymnNumber: Int
    var title: String
    var firstLine: String
    var lyrics: String
    var meter: String?
    var seasons: [String]
    var topics: [String]
    var scriptureReferences: [String]
    var tuneName: String?
    var musicalKey: String?
    var authors: String?
    var massParts: [String]
    var videoURLs: [String]
    var audioURLs: [String]
    var sheetMusicURLs: [String]
    var isPublicDomain: Bool
    var permissionGranted: Bool
    var backgroundNotes: String?
    var searchKey: String
    @Relationship(deleteRule: .cascade, inverse: \HymnSectionRecord.hymn)
    var sections: [HymnSectionRecord]

    init(
        id: String,
        language: String,
        hymnNumber: Int,
        title: String,
        firstLine: String,
        lyrics: String,
        meter: String? = nil,
        seasons: [String] = [],
        topics: [String] = [],
        scriptureReferences: [String] = [],
        tuneName: String? = nil,
        musicalKey: String? = nil,
        authors: String? = nil,
        massParts: [String] = [],
        videoURLs: [String] = [],
        audioURLs: [String] = [],
        sheetMusicURLs: [String] = [],
        isPublicDomain: Bool = false,
        permissionGranted: Bool = false,
        backgroundNotes: String? = nil,
        searchKey: String,
        sections: [HymnSectionRecord] = []
    ) {
        self.id = id
        self.language = language
        self.hymnNumber = hymnNumber
        self.title = title
        self.firstLine = firstLine
        self.lyrics = lyrics
        self.meter = meter
        self.seasons = seasons
        self.topics = topics
        self.scriptureReferences = scriptureReferences
        self.tuneName = tuneName
        self.musicalKey = musicalKey
        self.authors = authors
        self.massParts = massParts
        self.videoURLs = videoURLs
        self.audioURLs = audioURLs
        self.sheetMusicURLs = sheetMusicURLs
        self.isPublicDomain = isPublicDomain
        self.permissionGranted = permissionGranted
        self.backgroundNotes = backgroundNotes
        self.searchKey = searchKey
        self.sections = sections
    }
}

@Model
nonisolated final class HymnSectionRecord {
    var id: String
    var typeRaw: String
    var label: String
    var content: String
    var position: Int
    var hymn: HymnRecord?

    init(id: String, typeRaw: String, label: String, content: String, position: Int) {
        self.id = id
        self.typeRaw = typeRaw
        self.label = label
        self.content = content
        self.position = position
    }
}

/// A saved hymn, prayer, or litany. One row per item, in the shape the account sends:
/// `type`, `id`, `packId`, `titleSnapshot`, `createdAt`. A removal is not a row here. It is kept
/// with `deletedAt` until the account has it. The key is `type|id|packId`. `language` stays on
/// the device so a removed pack can still be named.
@Model
final class Bookmark {
    @Attribute(.unique) var key: String
    var type: String
    var itemId: String
    /// Catalog pack the item was saved from (`hymns-en`, `litanies-ig`, …).
    var packId: String = ""
    var titleSnapshot: String
    /// Language code derived from `packId`, kept for rows and hymn retargeting.
    var language: String = ""
    var createdAt: Date

    init(
        type: String,
        itemId: String,
        titleSnapshot: String,
        packId: String = "",
        language: String = "",
        createdAt: Date
    ) {
        let resolvedPack = packId.isEmpty && !language.isEmpty
            ? BookmarkType.packId(type: type, language: language)
            : packId
        let resolvedLanguage = language.isEmpty
            ? BookmarkType.languageCode(packId: resolvedPack, type: type)
            : language
        self.key = BookmarkType.key(type: type, id: itemId, packId: resolvedPack)
        self.type = type
        self.itemId = itemId
        self.packId = resolvedPack
        self.titleSnapshot = BookmarkType.clippedTitle(titleSnapshot)
        self.language = resolvedLanguage
        self.createdAt = createdAt
    }
}

@Model
final class HymnVisit {
    @Attribute(.unique) var hymnId: String
    var openedAt: Date

    init(hymnId: String, openedAt: Date) {
        self.hymnId = hymnId
        self.openedAt = openedAt
    }
}
