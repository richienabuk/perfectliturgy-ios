import Foundation
import SwiftData

/// Imports a Bible pack into the Bible store. Download replaces; sync pages upsert.
@ModelActor
actor BibleImporter {
    private static let chunkSize = 2_000

    /// Full download: delete the version's rows and insert the payload in one save. Rollback on failure.
    func replaceVersion(payload: BiblePackPayload, displayName: String) throws {
        let versionID = BiblePackReader.versionID(for: payload.packId)
        do {
            try deleteAll(versionID: versionID)
            try upsertBooks(payload.books, versionID: versionID)
            let live = payload.verses.filter { $0.deletedAt == nil }
            try insertVerses(live, versionID: versionID)
            try upsertVersion(
                id: versionID,
                packId: payload.packId,
                language: payload.language,
                displayName: displayName,
                revision: payload.revision,
                versification: payload.versification,
                coverageThrough: payload.coverageThrough
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// One sync page: upsert verses and books, apply tombstones, save. Does not touch PackFiles revision.
    func applyPage(payload: BiblePackPayload, displayName: String) throws {
        let versionID = BiblePackReader.versionID(for: payload.packId)
        do {
            if !payload.books.isEmpty {
                try upsertBooks(payload.books, versionID: versionID)
            }
            try applyVerseRows(payload.verses, versionID: versionID)
            try upsertVersion(
                id: versionID,
                packId: payload.packId,
                language: payload.language,
                displayName: displayName,
                revision: payload.revision,
                versification: payload.versification,
                coverageThrough: payload.coverageThrough
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func removeVersion(packId: String) throws {
        let versionID = BiblePackReader.versionID(for: packId)
        try deleteAll(versionID: versionID)
        try modelContext.save()
    }

    // MARK: - Private

    private func deleteAll(versionID: String) throws {
        let verses = try modelContext.fetch(
            FetchDescriptor<BibleVerse>(predicate: #Predicate { $0.versionID == versionID })
        )
        for row in verses { modelContext.delete(row) }
        let books = try modelContext.fetch(
            FetchDescriptor<BibleBook>(predicate: #Predicate { $0.versionID == versionID })
        )
        for row in books { modelContext.delete(row) }
        let versions = try modelContext.fetch(
            FetchDescriptor<BibleVersion>(predicate: #Predicate { $0.id == versionID })
        )
        for row in versions { modelContext.delete(row) }
    }

    private func upsertBooks(_ books: [BibleBookPayload], versionID: String) throws {
        guard !books.isEmpty else { return }
        let keys = books.map { BibleBook.key(versionID: versionID, bookID: $0.id) }
        let existing = try fetchBooks(keys: keys)
        var byKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.key, $0) })
        for book in books {
            let key = BibleBook.key(versionID: versionID, bookID: book.id)
            if let row = byKey[key] {
                row.order = book.order
                row.name = book.name
                row.abbr = book.abbr
            } else {
                let row = BibleBook(
                    versionID: versionID,
                    bookID: book.id,
                    order: book.order,
                    name: book.name,
                    abbr: book.abbr
                )
                modelContext.insert(row)
                byKey[key] = row
            }
        }
    }

    private func insertVerses(_ verses: [BibleVersePayload], versionID: String) throws {
        for chunk in chunk(verses, size: Self.chunkSize) {
            for verse in chunk {
                modelContext.insert(
                    BibleVerse(
                        versionID: versionID,
                        bookID: verse.book,
                        chapter: verse.chapter,
                        verse: verse.verse,
                        text: verse.text,
                        segmentsJSON: verse.segmentsJSON,
                        updatedAt: verse.updatedAt
                    )
                )
            }
        }
    }

    private func applyVerseRows(_ verses: [BibleVersePayload], versionID: String) throws {
        for chunk in chunk(verses, size: Self.chunkSize) {
            let keys = chunk.map {
                BibleVerse.key(
                    versionID: versionID,
                    bookID: $0.book,
                    pos: BibleVerse.pos(chapter: $0.chapter, verse: $0.verse)
                )
            }
            let existing = try fetchVerses(keys: keys)
            var byKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.key, $0) })
            for verse in chunk {
                let key = BibleVerse.key(
                    versionID: versionID,
                    bookID: verse.book,
                    pos: BibleVerse.pos(chapter: verse.chapter, verse: verse.verse)
                )
                if verse.deletedAt != nil {
                    if let row = byKey[key] {
                        modelContext.delete(row)
                        byKey[key] = nil
                    }
                    continue
                }
                if let row = byKey[key] {
                    row.text = verse.text
                    row.segmentsJSON = verse.segmentsJSON
                    row.updatedAt = verse.updatedAt
                } else {
                    let row = BibleVerse(
                        versionID: versionID,
                        bookID: verse.book,
                        chapter: verse.chapter,
                        verse: verse.verse,
                        text: verse.text,
                        segmentsJSON: verse.segmentsJSON,
                        updatedAt: verse.updatedAt
                    )
                    modelContext.insert(row)
                    byKey[key] = row
                }
            }
        }
    }

    private func upsertVersion(
        id: String,
        packId: String,
        language: String,
        displayName: String,
        revision: String,
        versification: String,
        coverageThrough: String?
    ) throws {
        var descriptor = FetchDescriptor<BibleVersion>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let row = try modelContext.fetch(descriptor).first {
            row.packId = packId
            row.language = language
            row.displayName = displayName
            row.abbr = id.uppercased()
            row.revision = revision
            row.versification = versification
            row.coverageThrough = coverageThrough
        } else {
            modelContext.insert(
                BibleVersion(
                    id: id,
                    packId: packId,
                    language: language,
                    displayName: displayName,
                    abbr: id.uppercased(),
                    revision: revision,
                    versification: versification,
                    coverageThrough: coverageThrough
                )
            )
        }
    }

    private func fetchVerses(keys: [String]) throws -> [BibleVerse] {
        guard !keys.isEmpty else { return [] }
        let predicate = #Predicate<BibleVerse> { keys.contains($0.key) }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
    }

    private func fetchBooks(keys: [String]) throws -> [BibleBook] {
        guard !keys.isEmpty else { return [] }
        let predicate = #Predicate<BibleBook> { keys.contains($0.key) }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
    }

    private func chunk<Element>(_ values: [Element], size: Int) -> [[Element]] {
        guard size > 0, !values.isEmpty else { return values.isEmpty ? [] : [values] }
        var result: [[Element]] = []
        var index = values.startIndex
        while index < values.endIndex {
            let next = values.index(index, offsetBy: size, limitedBy: values.endIndex) ?? values.endIndex
            result.append(Array(values[index..<next]))
            index = next
        }
        return result
    }
}
