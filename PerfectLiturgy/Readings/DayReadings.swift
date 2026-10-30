import Foundation

/// Resolved readings for one liturgical day (§9). Built by `ReadingResolver`.
nonisolated struct DayReadings: Equatable, Sendable {
    var key: String
    var sets: [ReadingSet]
}

nonisolated struct ReadingSet: Equatable, Sendable, Identifiable {
    /// Nil for the single default Mass. Otherwise the pack `set` id (`vigil`, `night`, …).
    var id: String?
    var label: String?
    var items: [ReadingItem]
}

nonisolated struct ReadingItem: Equatable, Sendable, Identifiable {
    /// Position in the day, stable for the session.
    var id: Int
    var slot: String
    var label: String
    /// Index 0 is the default form. Further entries are alternatives.
    var forms: [ReadingForm]
    var refrain: String?
    var refrainRef: String?
    /// Empty unless the slot is an acclamation. Every phrase is offered for choice.
    var acclamationPhrases: [String]
    var selectedAcclamationIndex: Int
    var closing: String?
    var cf: Bool
}

nonisolated struct ReadingForm: Equatable, Sendable {
    var label: String?
    var reference: String
    var bookTitle: String?
    var theme: String?
    var incipit: String?
    /// Psalm response for this form. Alternatives may override the item refrain.
    var refrain: String?
    var refrainRef: String?
    var body: ReadingBody
}

nonisolated struct ReadingSpan: Equatable, Sendable {
    var text: String
    var style: String?
}

nonisolated struct VerseText: Equatable, Sendable {
    var chapter: Int
    var verse: Int
    var spans: [ReadingSpan]
}

nonisolated enum ReadingBody: Equatable, Sendable {
    case passage(verses: [VerseText], fullVerseShown: Bool)
    case psalm(stanzas: [[VerseText]])
    case lectionary(paragraphs: [String], stanzas: [[String]])
    case unavailable(Reason)

    enum Reason: Equatable, Sendable {
        case noVersion
        case notDownloaded
        case missingVerses
        case noLectionary
    }
}

/// Selected Bible version for passage bodies.
/// Calendar item `text` and `verse_overrides` still win when the pack supplies them.
nonisolated enum TextSource: Equatable, Sendable {
    /// Bible version id (pack id without the `readings-` prefix).
    case bible(versionID: String)
}

/// Installed Bible version metadata the resolver needs for language rules.
nonisolated struct BibleChoice: Equatable, Sendable {
    var id: String
    var language: String
}

/// Async verse lookup used by the resolver. `BibleReader` implements it; tests use a fake.
protocol VerseSource: Sendable {
    func verses(
        version: String,
        book: String,
        fromChapter: Int,
        fromVerse: Int,
        toChapter: Int,
        toVerse: Int
    ) async -> [StoredVerse]
}
