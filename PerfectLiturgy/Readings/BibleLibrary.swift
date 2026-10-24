import Foundation
import SwiftData

/// Applies a readings pack into the local Bible and reads a passage back.
enum BibleLibrary {
    /// Pack id `readings-rsvce` stores verses under `rsvce`.
    static func translationID(for packId: String) -> String {
        let prefix = "readings-"
        guard packId.hasPrefix(prefix) else { return packId }
        let rest = String(packId.dropFirst(prefix.count))
        return rest.isEmpty ? packId : rest
    }

    static func importPack(
        _ data: Data,
        pack: PackRecord,
        into context: ModelContext,
        anchor: CivilDate
    ) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope: ReadingsBody
        do {
            envelope = try decoder.decode(ReadingsBody.self, from: data)
        } catch {
            throw PackHTTPError.transport
        }
        let window = VerseWindow.normalized(envelope.metadata?.displayWindow ?? pack.metadata?.displayWindow)
        let translation = translationID(for: pack.packId)
        var index = Dictionary(uniqueKeysWithValues: try verses(translation: translation, in: context).map { ($0.id, $0) })
        var retained: Set<String> = []
        for row in envelope.data {
            guard let book = ScriptureReference.code(for: row.book) else { continue }
            let key = BibleVerseRecord.key(
                translation: translation,
                book: book,
                chapter: row.chapter,
                verse: row.verse
            )
            if let deleted = row.deletedAt, !deleted.isEmpty {
                if let existing = index.removeValue(forKey: key) {
                    context.delete(existing)
                }
                retained.remove(key)
                continue
            }
            guard
                let text = row.text,
                !text.isEmpty,
                let date = VerseDate.parse(row.date),
                VerseWindow.contains(date, window: window, anchor: anchor)
            else { continue }
            if let existing = index[key] {
                existing.text = text
            } else {
                let record = BibleVerseRecord(
                    translation: translation,
                    book: book,
                    chapter: row.chapter,
                    verse: row.verse,
                    text: text
                )
                context.insert(record)
                index[key] = record
            }
            retained.insert(key)
        }
        for (key, existing) in index where !retained.contains(key) {
            context.delete(existing)
        }

        if let version = try version(id: translation, in: context) {
            version.title = pack.displayName
            version.windowRaw = window
            version.anchorYear = anchor.year
            version.anchorMonth = anchor.month
            version.anchorDay = anchor.day
        } else {
            context.insert(
                BibleVersionRecord(id: translation, title: pack.displayName, windowRaw: window, anchor: anchor)
            )
        }
        try context.save()
    }

    static func remove(translation: String, in context: ModelContext) throws {
        for row in try verses(translation: translation, in: context) {
            context.delete(row)
        }
        if let version = try version(id: translation, in: context) {
            context.delete(version)
        }
        try context.save()
    }

    static func count(translation: String, in context: ModelContext) throws -> Int {
        try verses(translation: translation, in: context).count
    }

    private static func verses(translation: String, in context: ModelContext) throws -> [BibleVerseRecord] {
        let translation = translation
        let descriptor = FetchDescriptor<BibleVerseRecord>(predicate: #Predicate { $0.translation == translation })
        return try context.fetch(descriptor).filter { !$0.isDeleted }
    }

    private static func version(id: String, in context: ModelContext) throws -> BibleVersionRecord? {
        let id = id
        var descriptor = FetchDescriptor<BibleVersionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first { !$0.isDeleted }
    }
}

/// Verse text for one citation. Nil means the Readings screen keeps the reference.
enum BiblePassage {
    static func text(
        reference: String,
        translation: String,
        on date: CivilDate,
        window: String,
        anchor: CivilDate,
        in context: ModelContext
    ) -> String? {
        guard VerseWindow.contains(date, window: window, anchor: anchor) else { return nil }
        guard let cited = ScriptureReference.verses(in: reference) else { return nil }
        var lines: [String] = []
        var seen: Set<String> = []
        for point in cited {
            let key = BibleVerseRecord.key(
                translation: translation,
                book: point.book,
                chapter: point.chapter,
                verse: point.verse
            )
            guard seen.insert(key).inserted else { continue }
            guard let record = try? verse(id: key, in: context), !record.text.isEmpty else { return nil }
            lines.append(record.text)
        }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: " ")
    }

    private static func verse(id: String, in context: ModelContext) throws -> BibleVerseRecord? {
        let id = id
        var descriptor = FetchDescriptor<BibleVerseRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first { !$0.isDeleted }
    }
}

enum VerseDate {
    static func parse(_ value: String?) -> CivilDate? {
        guard let value else { return nil }
        let day = value.prefix(10)
        let parts = day.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return nil
        }
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return CivilDate(year: year, month: month, day: day)
    }
}

extension VerseWindow {
    static func normalized(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case week: week
        case month: month
        default: day
        }
    }
}

private struct ReadingsBody: Decodable {
    var metadata: PackMetadata?
    var data: [ReadingsVerse]
}

private struct ReadingsVerse: Decodable {
    var book: String
    var chapter: Int
    var verse: Int
    var text: String?
    var date: String?
    var deletedAt: String?
}
