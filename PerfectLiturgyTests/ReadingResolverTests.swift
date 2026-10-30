import Foundation
import Testing
@testable import PerfectLiturgy

@Test func `Holy Saturday keeps seven first readings and eight psalms in order`() async throws {
    let seed = try loadSeedLectionary()
    let day = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 4, day: 4))
    #expect(day.id == "holy-saturday")
    let resolved = await ReadingResolver.resolve(
        day: day,
        lectionary: seed,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false
    )
    #expect(resolved.sets.count == 1)
    let items = try #require(resolved.sets.first).items
    #expect(items.filter { $0.slot == "first" }.count == 7)
    #expect(items.filter { $0.slot == "psalm" }.count == 8)
    let slots = items.map(\.slot)
    #expect(slots.prefix(14) == [
        "first", "psalm", "first", "psalm", "first", "psalm", "first", "psalm",
        "first", "psalm", "first", "psalm", "first", "psalm",
    ])
    #expect(items.map(\.label).prefix(3) == ["Reading 1", "Responsorial psalm", "Reading 2"])
}

@Test func `Christmas has four Mass sets`() async throws {
    let lectionary = christmasLectionary()
    let day = LiturgicalDay(
        id: "christmas",
        title: "The Nativity of the Lord",
        color: .white,
        season: .christmas,
        rank: .solemnity,
        weekMark: nil,
        fromCountryCalendar: false,
        readingKey: "christmas|A|II"
    )
    let resolved = await ReadingResolver.resolve(
        day: day,
        lectionary: lectionary,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false
    )
    #expect(resolved.sets.map(\.id) == ["vigil", "night", "dawn", "day"])
    #expect(resolved.sets.map(\.label) == [
        "Test Vigil Mass", "Test Mass during the Night", "Test Mass at Dawn", "Test Mass during the Day",
    ])
    #expect(resolved.sets.allSatisfy { $0.items.count == 2 })
}

@Test func `Lent returns every Lent phrase and Ordinary Time uses the default list`() async throws {
    let lectionary = phraseLectionary()
    let lent = await ReadingResolver.resolve(
        day: day(id: "lent-feria-1-monday", season: .lent, key: "lent-feria-1-monday|A|II"),
        lectionary: lectionary,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false
    )
    let lentItem = try #require(lent.sets.first?.items.first { $0.slot == "acclamation" })
    #expect(lentItem.acclamationPhrases == ["Test Lent acclamation", "Test Lent alternative"])

    let ordinary = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-29", season: .ordinary, key: "ot-sunday-29|A|II"),
        lectionary: lectionary,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false
    )
    let ordinaryItem = try #require(ordinary.sets.first?.items.first { $0.slot == "acclamation" })
    #expect(ordinaryItem.acclamationPhrases == ["Test Alleluia"])
}

@Test func `a seed-only day has an empty acclamation phrase list`() async throws {
    let seed = try loadSeedLectionary()
    #expect(seed.formulas.acclamation.isEmpty)
    let day = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 10, day: 18))
    let resolved = await ReadingResolver.resolve(
        day: day,
        lectionary: seed,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false
    )
    let acclamation = try #require(resolved.sets.first?.items.first { $0.slot == "acclamation" })
    #expect(acclamation.acclamationPhrases.isEmpty)
    #expect(acclamation.closing == nil)
}

@Test func `a matching calendar falls back to the Latin Rite seed for a missing day`() async throws {
    let seed = try loadSeedLectionary()
    let sparse = Lectionary(
        id: "calendar-sparse-en",
        language: "en",
        displayName: "Sparse",
        revision: "1",
        formulas: LectionaryFormulas(
            sets: [:],
            slots: ["first": LectionarySlotFormula(label: "First reading", closing: "Test closing.")],
            bookTitles: [:],
            acclamation: ["ordinary_time": ["Test Alleluia"]]
        ),
        sunday: [:],
        feria: [:],
        proper: [:],
        days: []
    )
    let day = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 10, day: 18))
    let withoutFallback = await ReadingResolver.resolve(
        day: day,
        lectionary: sparse,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false
    )
    #expect(withoutFallback.sets.isEmpty)

    let resolved = await ReadingResolver.resolve(
        day: day,
        lectionary: sparse,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false,
        fallback: seed
    )
    #expect(!resolved.sets.isEmpty)
    let first = try #require(resolved.sets.first?.items.first { $0.slot == "first" })
    #expect(first.label == "First reading")
    #expect(first.closing == "Test closing.")
    let reference = try #require(first.forms.first?.reference)
    #expect(reference == "Isaiah 45:1, 4-6")
    let acclamation = try #require(resolved.sets.first?.items.first { $0.slot == "acclamation" })
    #expect(acclamation.acclamationPhrases == ["Test Alleluia"])
    #expect(acclamation.forms.first?.bookTitle == nil)
    #expect(acclamation.forms.first?.theme == nil)
    #expect(acclamation.forms.first?.incipit == nil)

    let otherLanguage = Lectionary(
        id: "calendar-sparse-la",
        language: "la",
        displayName: "Sparse Latin",
        revision: "1",
        formulas: .empty,
        sunday: [:],
        feria: [:],
        proper: [:],
        days: []
    )
    let blocked = await ReadingResolver.resolve(
        day: day,
        lectionary: otherLanguage,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerses(),
        includeText: false,
        fallback: seed
    )
    #expect(blocked.sets.isEmpty)
}

@Test func `calendar text is used even when a Bible version is selected`() async throws {
    let lectionary = Lectionary(
        id: "calendar-en",
        language: "en",
        displayName: "Test calendar",
        revision: "1",
        formulas: .empty,
        sunday: [
            "ot-sunday-1|A": [
                LectionaryItem(
                    slot: "psalm",
                    reference: "Psalm 1:1-2",
                    ranges: [VerseRange(book: "PSA", from: "1:1", to: "1:2", continues: false)],
                    set: nil,
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: "Test refrain.",
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: .stanzas([
                        ["Test calendar psalm line one", "Test calendar psalm line two"],
                    ])
                ),
                LectionaryItem(
                    slot: "acclamation",
                    reference: "John 10:27",
                    ranges: [VerseRange(book: "JHN", from: "10:27", to: "10:27", continues: false)],
                    set: nil,
                    label: "Alleluia",
                    incipit: nil,
                    theme: nil,
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: .paragraphs(["Test calendar alleluia verse."])
                ),
                LectionaryItem(
                    slot: "first",
                    reference: "Isaiah 1:1",
                    ranges: [VerseRange(book: "ISA", from: "1:1", to: "1:1", continues: false)],
                    set: nil,
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: .paragraphs(["Test calendar first reading paragraph."])
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
    let verses = FakeVerses(store: [
        "PSA|1|1": StoredVerse(chapter: 1, verse: 1, text: "Test bible psalm."),
        "PSA|1|2": StoredVerse(chapter: 1, verse: 2, text: "Test bible psalm two."),
        "JHN|10|27": StoredVerse(chapter: 10, verse: 27, text: "Test bible alleluia."),
        "ISA|1|1": StoredVerse(chapter: 1, verse: 1, text: "Test bible first."),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-1", season: .ordinary, key: "ot-sunday-1|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    let psalm = try #require(resolved.sets.first?.items.first { $0.slot == "psalm" })
    #expect(psalm.forms.first?.body == .lectionary(
        paragraphs: [],
        stanzas: [["Test calendar psalm line one", "Test calendar psalm line two"]]
    ))
    let acclamation = try #require(resolved.sets.first?.items.first { $0.slot == "acclamation" })
    #expect(acclamation.forms.first?.body == .lectionary(
        paragraphs: ["Test calendar alleluia verse."],
        stanzas: []
    ))
    let first = try #require(resolved.sets.first?.items.first { $0.slot == "first" })
    #expect(first.forms.first?.body == .lectionary(
        paragraphs: ["Test calendar first reading paragraph."],
        stanzas: []
    ))
}

@Test func `verse overrides replace matching Bible verses`() async throws {
    let lectionary = Lectionary(
        id: "calendar-en",
        language: "en",
        displayName: "Test calendar",
        revision: "1",
        formulas: LectionaryFormulas(
            sets: [:],
            slots: ["gospel": LectionarySlotFormula(label: "Test Gospel", closing: nil)],
            bookTitles: ["MAT": "Test: A reading from the holy Gospel according to Matthew"],
            acclamation: [:]
        ),
        sunday: [
            "ot-sunday-1|A": [
                LectionaryItem(
                    slot: "gospel",
                    reference: "Matthew 19:3-4",
                    ranges: [VerseRange(book: "MAT", from: "19:3", to: "19:4", continues: false)],
                    set: nil,
                    label: nil,
                    incipit: "At that time:",
                    theme: "Test gospel theme.",
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: nil,
                    verseOverrides: [
                        VerseOverride(
                            book: "MAT",
                            chapter: 19,
                            verse: 3,
                            text: "Pharisees came up to Jesus and tested him by asking, “Is it lawful to divorce one’s wife for any cause?"
                        ),
                    ]
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
    let verses = FakeVerses(store: [
        "MAT|19|3": StoredVerse(chapter: 19, verse: 3, text: "Test bible matthew nineteen three."),
        "MAT|19|4": StoredVerse(chapter: 19, verse: 4, text: "Test bible matthew nineteen four."),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-1", season: .ordinary, key: "ot-sunday-1|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    let form = try #require(resolved.sets.first?.items.first?.forms.first)
    #expect(form.incipit == "At that time:")
    guard case .passage(let rows, _) = form.body else {
        Issue.record("Expected a passage body.")
        return
    }
    #expect(rows.count == 2)
    #expect(rows[0].spans.map(\.text) == [
        "Pharisees came up to Jesus and tested him by asking, “Is it lawful to divorce one’s wife for any cause?",
    ])
    #expect(rows[1].spans.map(\.text) == ["Test bible matthew nineteen four."])
}

@Test func `a first reading carries incipit theme book title and closing`() async throws {
    let lectionary = firstReadingLectionary()
    let verses = FakeVerses(store: [
        "EPH|4|32": StoredVerse(chapter: 4, verse: 32, text: "Test verse thirty-two."),
        "EPH|5|8": StoredVerse(chapter: 5, verse: 8, text: "Test verse eight."),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-29", season: .ordinary, key: "ot-sunday-29|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    let item = try #require(resolved.sets.first?.items.first)
    let form = try #require(item.forms.first)
    #expect(item.label == "Test First Reading")
    #expect(item.closing == "Test closing.")
    #expect(form.theme == "Test theme line.")
    #expect(form.incipit == "Test incipit:")
    #expect(form.bookTitle == "Test: A reading from the Letter to the Ephesians")
    #expect(form.reference == "Test Letter 4:32-5:8")
    guard case .passage(let rows, let full) = form.body else {
        Issue.record("Expected a passage body.")
        return
    }
    #expect(!full)
    #expect(rows.map(\.verse) == [32, 8])
}

@Test func `a psalm continues range joins the previous stanza`() async throws {
    let lectionary = psalmLectionary()
    let verses = FakeVerses(store: [
        "PSA|1|1": StoredVerse(chapter: 1, verse: 1, text: "Test line one"),
        "PSA|1|2": StoredVerse(chapter: 1, verse: 2, text: "Test line two"),
        "PSA|1|3": StoredVerse(chapter: 1, verse: 3, text: "Test line three"),
        "PSA|1|4": StoredVerse(chapter: 1, verse: 4, text: "Test line four"),
        "PSA|1|6": StoredVerse(chapter: 1, verse: 6, text: "Test line six"),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-29", season: .ordinary, key: "ot-sunday-29|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    let form = try #require(resolved.sets.first?.items.first?.forms.first)
    guard case .psalm(let stanzas) = form.body else {
        Issue.record("Expected a psalm body.")
        return
    }
    #expect(stanzas.count == 3)
    #expect(stanzas[0].map(\.verse) == [1, 2])
    #expect(stanzas[1].map(\.verse) == [3])
    #expect(stanzas[2].map(\.verse) == [4, 6])
}

@Test func `a gospel alternative keeps its own passage`() async throws {
    let lectionary = alternativeLectionary()
    let verses = FakeVerses(store: [
        "JHN|20|1": StoredVerse(chapter: 20, verse: 1, text: "Test John."),
        "JHN|20|9": StoredVerse(chapter: 20, verse: 9, text: "Test John end."),
        "LUK|24|13": StoredVerse(chapter: 24, verse: 13, text: "Test Luke."),
        "LUK|24|35": StoredVerse(chapter: 24, verse: 35, text: "Test Luke end."),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "easter-sunday", season: .easter, key: "easter-sunday|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    let item = try #require(resolved.sets.first?.items.first)
    #expect(item.forms.count == 2)
    #expect(item.forms[0].reference == "Test Gospel 20:1-9")
    #expect(item.forms[0].incipit == "Test incipit")
    #expect(item.forms[1].label == "Test: alternative reading")
    #expect(item.forms[1].reference == "Test Gospel 24:13-35")
    #expect(item.forms[1].incipit == "Test incipit two")
    #expect(item.forms[0].theme == "Test theme")
    #expect(item.forms[1].theme == "Test theme two")
}

@Test func `a psalm alternative keeps its own refrain`() async throws {
    let lectionary = Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: .empty,
        sunday: [
            "ot-sunday-1|A": [
                LectionaryItem(
                    slot: "psalm",
                    reference: "Psalm 16:1-2",
                    ranges: [VerseRange(book: "PSA", from: "16:1", to: "16:2", continues: false)],
                    set: nil,
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: "Test refrain default.",
                    refrainRef: "1a",
                    closing: nil,
                    cf: false,
                    alternatives: [
                        LectionaryAlternative(
                            label: "Or",
                            reference: "Psalm 16:5-8",
                            ranges: [VerseRange(book: "PSA", from: "16:5", to: "16:8", continues: false)],
                            incipit: nil,
                            theme: nil,
                            refrain: "Test refrain alternative.",
                            refrainRef: "5a",
                            text: nil
                        ),
                    ],
                    text: nil
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
    let verses = FakeVerses(store: [
        "PSA|16|1": StoredVerse(chapter: 16, verse: 1, text: "Test psalm one."),
        "PSA|16|2": StoredVerse(chapter: 16, verse: 2, text: "Test psalm two."),
        "PSA|16|5": StoredVerse(chapter: 16, verse: 5, text: "Test psalm five."),
        "PSA|16|8": StoredVerse(chapter: 16, verse: 8, text: "Test psalm eight."),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-1", season: .ordinary, key: "ot-sunday-1|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    let item = try #require(resolved.sets.first?.items.first)
    #expect(item.forms.count == 2)
    #expect(item.forms[0].refrain == "Test refrain default.")
    #expect(item.forms[0].refrainRef == "1a")
    #expect(item.forms[1].refrain == "Test refrain alternative.")
    #expect(item.forms[1].refrainRef == "5a")
    #expect(item.forms[1].reference == "Psalm 16:5-8")
}

@Test func `partial verses slice by part letter and fall back to the full verse`() async throws {
    let segments = try String(
        data: JSONEncoder().encode([
            BibleSegment(t: "Test part a. ", part: "a"),
            BibleSegment(t: "Test part b. ", part: "b", style: "quote"),
            BibleSegment(t: "Test part c.", part: "c"),
        ]),
        encoding: .utf8
    )
    let withParts = FakeVerses(store: [
        "ISA|7|14": StoredVerse(
            chapter: 7,
            verse: 14,
            text: "Test part a. Test part b. Test part c.",
            segmentsJSON: segments
        ),
    ])
    let sliced = await resolveRange(
        from: "7:14b",
        to: "7:14b",
        verses: withParts
    )
    guard case .passage(let rows, let full) = sliced else {
        Issue.record("Expected a passage.")
        return
    }
    #expect(!full)
    #expect(rows.first?.spans.map(\.text) == ["Test part b. "])
    #expect(rows.first?.spans.first?.style == "quote")

    let whole = FakeVerses(store: [
        "ISA|7|14": StoredVerse(chapter: 7, verse: 14, text: "Test whole verse."),
    ])
    let fallback = await resolveRange(from: "7:14b", to: "7:14b", verses: whole)
    guard case .passage(let fallbackRows, let shown) = fallback else {
        Issue.record("Expected a passage.")
        return
    }
    #expect(shown)
    #expect(fallbackRows.first?.spans.map(\.text) == ["Test whole verse."])
}

@Test func `quoted spans keep their style across verses`() async throws {
    let first = try String(
        data: JSONEncoder().encode([BibleSegment(t: "Test quote start ", style: "quote")]),
        encoding: .utf8
    )
    let second = try String(
        data: JSONEncoder().encode([BibleSegment(t: "and end.", style: "quote")]),
        encoding: .utf8
    )
    let verses = FakeVerses(store: [
        "ISA|7|14": StoredVerse(chapter: 7, verse: 14, text: "Test quote start ", segmentsJSON: first),
        "ISA|7|15": StoredVerse(chapter: 7, verse: 15, text: "and end.", segmentsJSON: second),
    ])
    let body = await resolveRange(from: "7:14", to: "7:15", verses: verses)
    guard case .passage(let rows, _) = body else {
        Issue.record("Expected a passage.")
        return
    }
    #expect(rows.flatMap(\.spans).map(\.style) == ["quote", "quote"])
}

@Test func `a language mismatch hides the incipit`() async throws {
    let lectionary = firstReadingLectionary()
    let verses = FakeVerses(store: [
        "EPH|4|32": StoredVerse(chapter: 4, verse: 32, text: "Test verse."),
        "EPH|5|8": StoredVerse(chapter: 5, verse: 8, text: "Test verse."),
    ])
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-29", season: .ordinary, key: "ot-sunday-29|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "la"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    #expect(resolved.sets.first?.items.first?.forms.first?.incipit == nil)
}

@Test func `a missing verse returns unavailable and a missing closing stays nil`() async throws {
    let lectionary = firstReadingLectionary(includeClosing: false)
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-29", season: .ordinary, key: "ot-sunday-29|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: EmptyVerses()
    )
    let item = try #require(resolved.sets.first?.items.first)
    #expect(item.closing == nil)
    guard case .unavailable(.missingVerses) = item.forms.first?.body else {
        Issue.record("Expected missing verses.")
        return
    }
}

@Test func `the conformance fixture phrase lists match the sample calendar pack`() throws {
    let bundle = Bundle(for: ResolverFixtureBundle.self)
    let url = try #require(bundle.url(forResource: "calendar-test-en", withExtension: "json"))
    let pack = try CalendarPackReader.decode(Data(contentsOf: url))
    #expect(pack.formulas.acclamation["lent"] == [
        "Test phrase 11", "Test phrase 12", "Test phrase 13", "Test phrase 14",
    ])
    #expect(pack.formulas.acclamation["default"] == ["Test phrase 17"])

    let seed = try loadSeedLectionary()
    let holySaturday = LatinRiteCalendar.day(on: CivilDate(year: 2026, month: 4, day: 4))
    let items = LectionaryKey.items(for: holySaturday, in: seed)
    #expect(items.filter { $0.slot == "first" }.count == 7)
    #expect(items.filter { $0.slot == "psalm" }.count == 8)
}

private final class ResolverFixtureBundle {}

private func loadSeedLectionary() throws -> Lectionary {
    let bundle = Bundle(for: DesignPreferences.self)
    let url = try #require(bundle.url(forResource: "lectionary-latin-rite", withExtension: "json"))
    return try LectionaryStore.decode(Data(contentsOf: url))
}

// MARK: - Helpers

private struct EmptyVerses: VerseSource {
    func verses(
        version: String,
        book: String,
        fromChapter: Int,
        fromVerse: Int,
        toChapter: Int,
        toVerse: Int
    ) async -> [StoredVerse] {
        []
    }
}

private struct FakeVerses: VerseSource {
    var store: [String: StoredVerse]

    func verses(
        version: String,
        book: String,
        fromChapter: Int,
        fromVerse: Int,
        toChapter: Int,
        toVerse: Int
    ) async -> [StoredVerse] {
        var rows: [StoredVerse] = []
        var chapter = fromChapter
        var verse = fromVerse
        while (chapter, verse) <= (toChapter, toVerse) {
            if let row = store["\(book)|\(chapter)|\(verse)"] {
                rows.append(row)
            }
            verse += 1
            if verse > 200 {
                verse = 1
                chapter += 1
            }
            if chapter > toChapter + 1 { break }
        }
        return rows
    }
}

private func day(id: String, season: LiturgicalSeason, key: String) -> LiturgicalDay {
    LiturgicalDay(
        id: id,
        title: id,
        color: .green,
        season: season,
        rank: .feria,
        weekMark: nil,
        fromCountryCalendar: false,
        readingKey: key
    )
}

private func resolveRange(from: String, to: String, verses: some VerseSource) async -> ReadingBody {
    let lectionary = Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: .empty,
        sunday: [
            "ot-sunday-29|A": [
                LectionaryItem(
                    slot: "first",
                    reference: "Test",
                    ranges: [VerseRange(book: "ISA", from: from, to: to, continues: false)],
                    set: nil,
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: nil
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
    let resolved = await ReadingResolver.resolve(
        day: day(id: "ot-sunday-29", season: .ordinary, key: "ot-sunday-29|A|II"),
        lectionary: lectionary,
        bible: BibleChoice(id: "test", language: "en"),
        source: .bible(versionID: "test"),
        verses: verses
    )
    return resolved.sets.first?.items.first?.forms.first?.body ?? .unavailable(.missingVerses)
}

private func christmasLectionary() -> Lectionary {
    func items(set: String) -> [LectionaryItem] {
        [
            LectionaryItem(
                slot: "first",
                reference: "Test \(set) first",
                ranges: [],
                set: set,
                label: nil,
                incipit: nil,
                theme: nil,
                refrain: nil,
                refrainRef: nil,
                closing: nil,
                cf: false,
                alternatives: [],
                text: nil
            ),
            LectionaryItem(
                slot: "gospel",
                reference: "Test \(set) gospel",
                ranges: [],
                set: set,
                label: nil,
                incipit: nil,
                theme: nil,
                refrain: nil,
                refrainRef: nil,
                closing: nil,
                cf: false,
                alternatives: [],
                text: nil
            ),
        ]
    }
    return Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: LectionaryFormulas(
            sets: [
                "vigil": "Test Vigil Mass",
                "night": "Test Mass during the Night",
                "dawn": "Test Mass at Dawn",
                "day": "Test Mass during the Day",
            ],
            slots: [:],
            bookTitles: [:],
            acclamation: [:]
        ),
        sunday: [
            "christmas|A": items(set: "vigil") + items(set: "night") + items(set: "dawn") + items(set: "day"),
        ],
        feria: [:],
        proper: [:],
        days: []
    )
}

private func phraseLectionary() -> Lectionary {
    let acclamation = LectionaryItem(
        slot: "acclamation",
        reference: "Test verse",
        ranges: [],
        set: nil,
        label: nil,
        incipit: nil,
        theme: nil,
        refrain: nil,
        refrainRef: nil,
        closing: nil,
        cf: false,
        alternatives: [],
        text: nil
    )
    return Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: LectionaryFormulas(
            sets: [:],
            slots: ["acclamation": LectionarySlotFormula(label: "Test Gospel Acclamation", closing: nil)],
            bookTitles: [:],
            acclamation: [
                "lent": ["Test Lent acclamation", "Test Lent alternative"],
                "default": ["Test Alleluia"],
            ]
        ),
        sunday: ["ot-sunday-29|A": [acclamation]],
        feria: [:],
        proper: ["lent-feria-1-monday": [acclamation]],
        days: []
    )
}

private func firstReadingLectionary(includeClosing: Bool = true) -> Lectionary {
    Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: LectionaryFormulas(
            sets: [:],
            slots: [
                "first": LectionarySlotFormula(
                    label: "Test First Reading",
                    closing: includeClosing ? "Test closing." : nil
                ),
            ],
            bookTitles: ["EPH": "Test: A reading from the Letter to the Ephesians"],
            acclamation: [:]
        ),
        sunday: [
            "ot-sunday-29|A": [
                LectionaryItem(
                    slot: "first",
                    reference: "Test Letter 4:32-5:8",
                    ranges: [VerseRange(book: "EPH", from: "4:32", to: "5:8", continues: false)],
                    set: nil,
                    label: nil,
                    incipit: "Test incipit:",
                    theme: "Test theme line.",
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: nil
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
}

private func psalmLectionary() -> Lectionary {
    Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: .empty,
        sunday: [
            "ot-sunday-29|A": [
                LectionaryItem(
                    slot: "psalm",
                    reference: "Test Psalm 1:1-2, 3, 4 and 6",
                    ranges: [
                        VerseRange(book: "PSA", from: "1:1", to: "1:2", continues: false),
                        VerseRange(book: "PSA", from: "1:3", to: "1:3", continues: false),
                        VerseRange(book: "PSA", from: "1:4", to: "1:4", continues: false),
                        VerseRange(book: "PSA", from: "1:6", to: "1:6", continues: true),
                    ],
                    set: nil,
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: "Test refrain line.",
                    refrainRef: "Test Book 5:1",
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: nil
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
}

private func alternativeLectionary() -> Lectionary {
    Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: .empty,
        sunday: [
            "easter-sunday|A": [
                LectionaryItem(
                    slot: "gospel",
                    reference: "Test Gospel 20:1-9",
                    ranges: [VerseRange(book: "JHN", from: "20:1", to: "20:9", continues: false)],
                    set: nil,
                    label: nil,
                    incipit: "Test incipit",
                    theme: "Test theme",
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [
                        LectionaryAlternative(
                            label: "Test: alternative reading",
                            reference: "Test Gospel 24:13-35",
                            ranges: [VerseRange(book: "LUK", from: "24:13", to: "24:35", continues: false)],
                            incipit: "Test incipit two",
                            theme: "Test theme two",
                            refrain: nil,
                            refrainRef: nil,
                            text: nil
                        ),
                    ],
                    text: nil
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
}
