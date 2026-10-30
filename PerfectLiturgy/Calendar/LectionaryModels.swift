import Foundation

/// One complete lectionary: the Latin Rite seed or a downloaded calendar pack.
nonisolated struct Lectionary: Equatable, Sendable {
    var id: String
    var language: String
    var displayName: String
    var revision: String
    var formulas: LectionaryFormulas
    var sunday: [String: [LectionaryItem]]
    var feria: [String: [LectionaryItem]]
    var proper: [String: [LectionaryItem]]
    var days: [CountryCelebration]

    static let empty = Lectionary(
        id: "",
        language: "",
        displayName: "",
        revision: "",
        formulas: .empty,
        sunday: [:],
        feria: [:],
        proper: [:],
        days: []
    )
}

nonisolated struct LectionaryFormulas: Equatable, Sendable {
    var sets: [String: String]
    var slots: [String: LectionarySlotFormula]
    var bookTitles: [String: String]
    var acclamation: [String: [String]]

    static let empty = LectionaryFormulas(sets: [:], slots: [:], bookTitles: [:], acclamation: [:])
}

nonisolated struct LectionarySlotFormula: Equatable, Sendable {
    var label: String?
    var closing: String?
}

/// One reading, psalm, or acclamation in proclamation order. The slot is an open string.
nonisolated struct LectionaryItem: Equatable, Sendable {
    var slot: String
    var reference: String?
    var ranges: [VerseRange]
    var set: String?
    var label: String?
    var incipit: String?
    var theme: String?
    var refrain: String?
    var refrainRef: String?
    var closing: String?
    var cf: Bool
    var alternatives: [LectionaryAlternative]
    var text: LectionaryBody?
    /// Replaces matching Bible verses when the calendar edits the wording.
    var verseOverrides: [VerseOverride] = []
}

nonisolated struct LectionaryAlternative: Equatable, Sendable {
    var label: String?
    var reference: String?
    var ranges: [VerseRange]
    var incipit: String?
    var theme: String?
    var refrain: String?
    var refrainRef: String?
    var text: LectionaryBody?
    var verseOverrides: [VerseOverride] = []
}

nonisolated struct VerseRange: Equatable, Sendable {
    var book: String
    var from: String
    var to: String
    var continues: Bool
}

/// One Bible verse the calendar replaces with lectionary wording.
nonisolated struct VerseOverride: Equatable, Sendable {
    var book: String
    var chapter: Int
    var verse: Int
    var text: String
}

nonisolated enum LectionaryBody: Equatable, Sendable {
    case paragraphs([String])
    case stanzas([[String]])
}

/// Shared day-key lookup for the active calendar (§5.9).
nonisolated enum LectionaryKey {
    /// Seasonal ferias are keyed by celebration id alone. Ordinary Time weekdays use the feria table.
    static let properPrefixes = [
        "lent-feria",
        "easter-feria",
        "advent-feria",
        "advent-december",
        "christmas-january",
        "christmas-octave",
        "after-epiphany",
        "easter-octave",
        "after-ash",
        "holy-week",
    ]

    static func items(for day: LiturgicalDay, in lectionary: Lectionary) -> [LectionaryItem] {
        let parts = day.readingKey.split(separator: "|").map(String.init)
        guard parts.count == 3 else { return [] }
        return items(id: parts[0], sundayCycle: parts[1], weekdayCycle: parts[2], in: lectionary)
    }

    static func items(
        id: String,
        sundayCycle: String,
        weekdayCycle: String,
        in lectionary: Lectionary
    ) -> [LectionaryItem] {
        if id.hasPrefix("ot-feria") {
            return lectionary.feria["\(id)|\(weekdayCycle)"] ?? []
        }
        if properPrefixes.contains(where: { id.hasPrefix($0) }) {
            return lectionary.proper[id] ?? []
        }
        if let sunday = lectionary.sunday["\(id)|\(sundayCycle)"], !sunday.isEmpty {
            return sunday
        }
        return lectionary.proper[id] ?? []
    }
}
