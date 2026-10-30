import Foundation
import SwiftData

/// Reads verses from the Bible store. Never returns model objects.
@ModelActor
actor BibleReader {
    func verses(
        versionID: String,
        bookID: String,
        fromChapter: Int,
        fromVerse: Int,
        toChapter: Int,
        toVerse: Int
    ) throws -> [StoredVerse] {
        let fromPos = BibleVerse.pos(chapter: fromChapter, verse: fromVerse)
        let toPos = BibleVerse.pos(chapter: toChapter, verse: toVerse)
        let predicate = #Predicate<BibleVerse> {
            $0.versionID == versionID && $0.bookID == bookID && $0.pos >= fromPos && $0.pos <= toPos
        }
        let rows = try modelContext.fetch(
            FetchDescriptor<BibleVerse>(predicate: predicate, sortBy: [SortDescriptor(\.pos)])
        )
        return rows.map {
            StoredVerse(chapter: $0.chapter, verse: $0.verse, text: $0.text, segmentsJSON: $0.segmentsJSON)
        }
    }

    /// True when the first and last verse of every range exist locally.
    func isAvailable(versionID: String, ranges: [VerseRange]) throws -> Bool {
        for range in ranges {
            guard let start = Self.parse(range.from), let end = Self.parse(range.to) else {
                return false
            }
            if try verse(versionID: versionID, bookID: range.book, chapter: start.chapter, verse: start.verse) == nil {
                return false
            }
            if try verse(versionID: versionID, bookID: range.book, chapter: end.chapter, verse: end.verse) == nil {
                return false
            }
        }
        return true
    }

    func versions() throws -> [BibleVersionChoice] {
        let rows = try modelContext.fetch(
            FetchDescriptor<BibleVersion>(sortBy: [SortDescriptor(\.displayName)])
        )
        return rows.map { BibleVersionChoice(id: $0.id, title: $0.displayName, language: $0.language) }
    }

    private func verse(versionID: String, bookID: String, chapter: Int, verse: Int) throws -> BibleVerse? {
        let key = BibleVerse.key(
            versionID: versionID,
            bookID: bookID,
            pos: BibleVerse.pos(chapter: chapter, verse: verse)
        )
        var descriptor = FetchDescriptor<BibleVerse>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Parses `chapter:verse` with an optional part letter. Part letters are ignored for availability.
    nonisolated static func parse(_ text: String) -> (chapter: Int, verse: Int)? {
        let pattern = #/^([1-9]\d*):([1-9]\d*)[a-z]?$/#
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        guard let chapter = Int(match.1), let verse = Int(match.2) else { return nil }
        return (chapter, verse)
    }
}
