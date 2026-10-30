import Foundation
import Testing
@testable import PerfectLiturgy

@Test func `the Latin Rite seed decodes into the new lectionary model`() async throws {
    let seed = await LectionaryStore.shared.seed(bundle: Bundle(for: DesignPreferences.self))
    #expect(seed.id == "latin-rite")
    #expect(seed.displayName == "Latin Rite")
    #expect(seed.language == "en")
    #expect(seed.formulas.slots["first"]?.label == "First reading")
    #expect(!seed.sunday.isEmpty)
    #expect(!seed.feria.isEmpty)
    #expect(!seed.proper.isEmpty)
    #expect(seed.days.isEmpty)
}

@Test func `LectionaryKey returns items for the dated Sundays and ferias`() async throws {
    let seed = await LectionaryStore.shared.seed(bundle: Bundle(for: DesignPreferences.self))
    let dates = [
        CivilDate(year: 2026, month: 10, day: 18),
        CivilDate(year: 2026, month: 10, day: 19),
        CivilDate(year: 2026, month: 10, day: 24),
        CivilDate(year: 2026, month: 2, day: 18),
        CivilDate(year: 2026, month: 11, day: 29),
        CivilDate(year: 2026, month: 6, day: 7),
        CivilDate(year: 2026, month: 11, day: 1),
    ]
    for date in dates {
        let day = LatinRiteCalendar.day(on: date)
        let count = LectionaryKey.items(for: day, in: seed).count
        #expect(count > 0, "\(date.year)-\(date.month)-\(date.day) \(day.readingKey)")
    }
}

@Test func `the placeholder calendar pack decodes with formulas and Mass sets`() throws {
    let url = try #require(
        Bundle(for: FixtureAnchor.self).url(forResource: "calendar-test-en", withExtension: "json")
    )
    let lectionary = try LectionaryStore.decode(Data(contentsOf: url))
    #expect(lectionary.id == "calendar-test-en")
    #expect(lectionary.formulas.acclamation["lent"]?.count == 4)
    let christmas = lectionary.sunday["christmas|B"] ?? []
    #expect(Set(christmas.compactMap(\.set)) == ["vigil", "night", "dawn", "day"])
    #expect(!lectionary.days.isEmpty)
}

@Test func `calendar packs decode verse overrides and incipits`() throws {
    let url = try #require(
        Bundle(for: FixtureAnchor.self).url(forResource: "calendar-test-en", withExtension: "json")
    )
    let lectionary = try LectionaryStore.decode(Data(contentsOf: url))
    let items = lectionary.sunday["easter-sunday-2|A"] ?? []
    let gospel = try #require(items.first { $0.slot == "gospel" })
    #expect(gospel.incipit == "Test incipit 116")
    #expect(gospel.verseOverrides == [
        VerseOverride(book: "MAT", chapter: 22, verse: 15, text: "Test line 117"),
    ])
}

private final class FixtureAnchor {}
