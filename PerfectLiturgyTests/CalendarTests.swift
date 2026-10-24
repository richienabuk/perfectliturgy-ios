import Foundation
import Testing
@testable import PerfectLiturgy

struct DatedCase: Sendable, CustomTestStringConvertible {
    var year: Int
    var month: Int
    var day: Int
    var title: String
    var color: LiturgicalColor?
    var weekMark: String?
    var clearsWeekMark = false
    var id: String?
    var key: String?
    var keySuffix: String?
    var slotCount: Int?
    var secondReading: Bool?

    var testDescription: String {
        "\(year)-\(month)-\(day) \(title)"
    }

    var date: CivilDate { CivilDate(year: year, month: month, day: day) }
}

@Test(arguments: [
    DatedCase(year: 2026, month: 10, day: 18, title: "29th Sunday in Ordinary Time", color: .green, weekMark: "XXIX", id: "ot-sunday-29", key: "ot-sunday-29|A|II", slotCount: 5),
    DatedCase(year: 2026, month: 10, day: 11, title: "28th Sunday in Ordinary Time", weekMark: "XXVIII", id: "ot-sunday-28"),
    DatedCase(year: 2025, month: 10, day: 18, title: "Saint Luke", color: .red, clearsWeekMark: true, id: "luke"),
    DatedCase(year: 2026, month: 10, day: 19, title: "Monday of the 29th week in Ordinary Time", color: .green, weekMark: "XXIX", secondReading: false),
    DatedCase(year: 2025, month: 12, day: 25, title: "The Nativity of the Lord", color: .white, id: "nativity"),
    DatedCase(year: 2026, month: 1, day: 6, title: "The Epiphany of the Lord", id: "epiphany"),
    DatedCase(year: 2026, month: 1, day: 4, title: "2nd Sunday after the Nativity of the Lord", id: "nativity-sunday-2"),
    DatedCase(year: 2026, month: 1, day: 11, title: "The Baptism of the Lord", id: "baptism"),
    DatedCase(year: 2026, month: 1, day: 12, title: "Monday of the 1st week in Ordinary Time", weekMark: "I"),
    DatedCase(year: 2026, month: 2, day: 18, title: "Ash Wednesday", color: .purple, id: "ash-wednesday", secondReading: true),
    DatedCase(year: 2026, month: 3, day: 29, title: "Palm Sunday of the Passion of the Lord", color: .red, id: "palm-sunday"),
    DatedCase(year: 2026, month: 4, day: 5, title: "Easter Sunday", color: .white, id: "easter-sunday"),
    DatedCase(year: 2026, month: 5, day: 14, title: "The Ascension of the Lord", id: "ascension"),
    DatedCase(year: 2026, month: 5, day: 17, title: "7th Sunday of Easter", id: "easter-sunday-7"),
    DatedCase(year: 2026, month: 5, day: 24, title: "Pentecost Sunday", color: .red, id: "pentecost"),
    DatedCase(year: 2026, month: 6, day: 4, title: "The Most Holy Body and Blood of Christ", id: "corpus-christi"),
    DatedCase(year: 2026, month: 6, day: 7, title: "10th Sunday in Ordinary Time", weekMark: "X", id: "ot-sunday-10"),
    DatedCase(year: 2026, month: 5, day: 25, title: "The Blessed Virgin Mary, Mother of the Church", color: .white, id: "mary-mother-of-the-church"),
    DatedCase(year: 2026, month: 5, day: 27, title: "Wednesday of the 8th week in Ordinary Time", weekMark: "VIII"),
    DatedCase(year: 2026, month: 11, day: 1, title: "All Saints", color: .white, clearsWeekMark: true, id: "all-saints"),
    DatedCase(year: 2026, month: 11, day: 22, title: "Our Lord Jesus Christ, King of the Universe", id: "christ-the-king"),
    DatedCase(year: 2026, month: 11, day: 23, title: "Monday of the 34th week in Ordinary Time", weekMark: "XXXIV"),
    DatedCase(year: 2026, month: 11, day: 29, title: "1st Sunday of Advent", color: .purple, id: "advent-sunday-1", keySuffix: "|B|I"),
    DatedCase(year: 2024, month: 12, day: 8, title: "2nd Sunday of Advent", id: "advent-sunday-2"),
    DatedCase(year: 2024, month: 12, day: 9, title: "The Immaculate Conception of the Blessed Virgin Mary", color: .white, id: "immaculate-conception"),
])
func `roman calendar matches the dated table`(_ expected: DatedCase) {
    let day = RomanCalendar.day(on: expected.date)
    #expect(day.title == expected.title)
    #expect(day.fromCountryCalendar == false)
    if let color = expected.color {
        #expect(day.color == color)
    }
    if let weekMark = expected.weekMark {
        #expect(day.weekMark == weekMark)
    }
    if expected.clearsWeekMark {
        #expect(day.weekMark == nil)
    }
    if let id = expected.id {
        #expect(day.id == id)
    }
    if let key = expected.key {
        #expect(day.readingKey == key)
    }
    if let suffix = expected.keySuffix {
        #expect(day.readingKey.hasSuffix(suffix))
    }
    if let slotCount = expected.slotCount {
        #expect(day.slots.count == slotCount)
    }
    if let secondReading = expected.secondReading {
        #expect(day.hasSecondReading == secondReading)
    }
}

@Test func `a country day replaces only the date it marks`() {
    let patron = CountryCelebration(
        id: "test-patron",
        title: "Test patron",
        color: .red,
        month: 10,
        day: 18
    )
    let sunday = RomanCalendar.day(on: CivilDate(year: 2026, month: 10, day: 18), country: [patron])
    let monday = RomanCalendar.day(on: CivilDate(year: 2026, month: 10, day: 19), country: [patron])

    #expect(sunday.title == "Test patron")
    #expect(sunday.color == .red)
    #expect(sunday.id == "country-test-patron")
    #expect(sunday.fromCountryCalendar == true)
    #expect(sunday.weekMark == nil)
    #expect(sunday.season == .ordinary)
    #expect(sunday.readingKey == "ot-sunday-29|A|II")
    #expect(sunday.slots.count == 5)

    #expect(monday.title == "Monday of the 29th week in Ordinary Time")
    #expect(monday.fromCountryCalendar == false)
    #expect(monday.id == "ot-feria-29-monday")
}

@Test func `a transferred country day leaves the roman ascension in place`() {
    let moved = CountryCelebration(
        id: "ascension",
        title: "The Ascension of the Lord",
        color: .white,
        month: 5,
        day: 17,
        year: 2026
    )
    let thursday = RomanCalendar.day(on: CivilDate(year: 2026, month: 5, day: 14), country: [moved])
    let sunday = RomanCalendar.day(on: CivilDate(year: 2026, month: 5, day: 17), country: [moved])
    let otherYear = RomanCalendar.day(on: CivilDate(year: 2027, month: 5, day: 17), country: [moved])

    #expect(thursday.title == "The Ascension of the Lord")
    #expect(thursday.id == "ascension")
    #expect(sunday.title == "The Ascension of the Lord")
    #expect(sunday.id == "country-ascension")
    #expect(sunday.fromCountryCalendar == true)
    #expect(sunday.readingKey == "easter-sunday-7|A|II")
    #expect(otherYear.fromCountryCalendar == false)
    #expect(otherYear.id != "country-ascension")
}

@Test func `holy saturday omits the second reading`() {
    let day = RomanCalendar.day(on: CivilDate(year: 2026, month: 4, day: 4))
    #expect(day.id == "holy-saturday")
    #expect(day.hasSecondReading == false)
    #expect(day.slots == [.first, .psalm, .acclamation, .gospel])
}

@Test func `today keeps references and does not carry verse text`() throws {
    let index = Lectionary.load()
    let page = TodayPageBuilder.page(for: CivilDate(year: 2026, month: 10, day: 24), lectionary: index)
    #expect(page.dateLine == "Saturday · 24 October 2026")
    #expect(page.title == "Saturday of the 29th week in Ordinary Time")
    #expect(page.weekMark == "XXIX")
    #expect(page.readings.map(\.label) == [
        "First reading",
        "Responsorial psalm",
        "Gospel acclamation",
        "Gospel",
    ])
    #expect(page.readings.map(\.reference) == [
        "Ephesians 4:7-16",
        "Psalm 122:1-2, 3-4ab, 4cd-5",
        "Ezekiel 33:11",
        "Luke 13:1-9",
    ])
}

@Test func `an ordinary weekday uses the feria table and the weekday cycle`() {
    let index = LectionaryIndex(
        sunday: ["ot-feria-29-saturday|A": [ReadingCitation(slot: .gospel, reference: "Wrong table")]],
        feria: ["ot-feria-29-saturday|II": [ReadingCitation(slot: .gospel, reference: "Luke 13:1-9")]],
        proper: ["ot-feria-29-saturday": [ReadingCitation(slot: .gospel, reference: "Wrong proper")]]
    )
    let day = RomanCalendar.day(on: CivilDate(year: 2026, month: 10, day: 24))
    let gospel = index.citations(for: day).first { $0.slot == .gospel }
    #expect(gospel?.reference == "Luke 13:1-9")
}

@Test func `a seasonal feria uses the proper table keyed by id`() {
    let index = LectionaryIndex(
        sunday: ["lent-feria-1-monday|A": [ReadingCitation(slot: .gospel, reference: "Wrong sunday")]],
        feria: [:],
        proper: ["lent-feria-1-monday": [ReadingCitation(slot: .gospel, reference: "Proper gospel")]]
    )
    let ash = CivilDate(year: 2026, month: 2, day: 18)
    let monday = ash.adding(days: 5)
    let day = RomanCalendar.day(on: monday)
    #expect(day.id == "lent-feria-1-monday")
    #expect(index.citations(for: day).first { $0.slot == .gospel }?.reference == "Proper gospel")
}

@Test func `every sunday in years A, B, and C has a gospel citation`() {
    let index = Lectionary.load()
    for year in [2026, 2027, 2025] {
        var date = RomanCalendar.firstSundayOfAdvent(year: year - 1)
        let end = RomanCalendar.firstSundayOfAdvent(year: year)
        while date < end {
            if date.weekday == .sunday {
                let day = RomanCalendar.day(on: date)
                let gospel = index.citations(for: day).first { $0.slot == .gospel }?.reference ?? ""
                #expect(!gospel.isEmpty, "\(date.year)-\(date.month)-\(date.day) \(day.readingKey)")
            }
            date = date.adding(days: 1)
        }
    }
}

@Test func `both weekday cycles cite every ordinary feria`() {
    let index = Lectionary.load()
    for week in 1...34 {
        for slug in ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday"] {
            for cycle in ["I", "II"] {
                let rows = index.feria["ot-feria-\(week)-\(slug)|\(cycle)"] ?? []
                #expect(rows.contains { $0.slot == .first && !$0.reference.isEmpty })
                #expect(rows.contains { $0.slot == .gospel && !$0.reference.isEmpty })
            }
        }
    }
    let yearI = index.feria["ot-feria-29-saturday|I"]?.first { $0.slot == .first }?.reference
    let yearII = index.feria["ot-feria-29-saturday|II"]?.first { $0.slot == .first }?.reference
    #expect(yearI != yearII)
    #expect(yearII == "Ephesians 4:7-16")
}

@Test func `other days prefer the sunday table then the proper table`() {
    let bySunday = LectionaryIndex(
        sunday: ["ash-wednesday|A": [ReadingCitation(slot: .first, reference: "Joel 2:12-18")]],
        feria: [:],
        proper: ["ash-wednesday": [ReadingCitation(slot: .first, reference: "Proper")]]
    )
    let byProper = LectionaryIndex(sunday: [:], feria: [:], proper: [
        "ash-wednesday": [ReadingCitation(slot: .first, reference: "Joel 2:12-18")],
    ])
    let day = RomanCalendar.day(on: CivilDate(year: 2026, month: 2, day: 18))
    #expect(bySunday.citations(for: day).first?.reference == "Joel 2:12-18")
    #expect(byProper.citations(for: day).first?.reference == "Joel 2:12-18")
}
