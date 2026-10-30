import Foundation
import Testing
@testable import PerfectLiturgy

/// Stage I0 checks. The seed is the bundled Latin Rite lectionary (citations and headings only).
/// The fixtures are placeholder packs. Shared with the Android app (readings plan §11, Stage I0).

private final class LatinRiteFixtureBundle {}

/// Every USFM book id the readings plan accepts (73 books, Catholic canon).
private let usfmBooks: Set<String> = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH",
    "EZR", "NEH", "TOB", "JDT", "ESG", "1MA", "2MA", "JOB", "PSA", "PRO", "ECC", "SNG", "WIS", "SIR",
    "ISA", "JER", "LAM", "BAR", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB",
    "ZEP", "HAG", "ZEC", "MAL",
    "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH",
    "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
]

/// Seed items with a reference and no `ranges`. Known content gaps, listed so a new one fails the test.
private let knownSeedItemsWithoutRanges: Set<String> = [
    "proper|lent-feria-1-thursday|first|Esther C:12, 14-16, 23-25",
    "proper|simon-and-jude|acclamation|Te Deum",
]

private func fixtureData(_ name: String) throws -> Data {
    let bundle = Bundle(for: LatinRiteFixtureBundle.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func seedJSON() throws -> [String: Any] {
    let bundle = Bundle(for: DesignPreferences.self)
    let url = try #require(bundle.url(forResource: "lectionary-latin-rite", withExtension: "json"))
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    return try #require(object as? [String: Any])
}

/// Every item in every section, with its section and day key.
private func seedItems(_ seed: [String: Any]) -> [(section: String, key: String, item: [String: Any])] {
    var rows: [(String, String, [String: Any])] = []
    for section in ["sunday", "feria", "proper"] {
        guard let days = seed[section] as? [String: Any] else { continue }
        for (key, value) in days {
            for item in (value as? [[String: Any]]) ?? [] {
                rows.append((section, key, item))
            }
        }
    }
    return rows
}

/// Parses `chapter:verse` with an optional part letter. Returns nil when the form is wrong.
private func parseVerse(_ text: String) -> (chapter: Int, verse: Int)? {
    let pattern = #/^([1-9]\d*):([1-9]\d*)[a-z]?$/#
    guard let match = text.wholeMatch(of: pattern) else { return nil }
    guard let chapter = Int(match.1), let verse = Int(match.2) else { return nil }
    return (chapter, verse)
}

@Test func `the seed identifies itself as the Latin Rite in English`() throws {
    let seed = try seedJSON()
    #expect(seed["calendar_id"] as? String == "latin-rite")
    #expect(seed["display_name"] as? String == "Latin Rite")
    #expect(seed["language"] as? String == "en")
    let formulas = try #require(seed["formulas"] as? [String: Any])
    let slots = try #require(formulas["slots"] as? [String: Any])
    #expect(Set(slots.keys) == ["first", "psalm", "second", "acclamation", "gospel"])
}

@Test func `the seed carries citations and headings only`() throws {
    let seed = try seedJSON()
    let itemKeys: Set<String> = ["slot", "reference", "ranges", "set", "label", "cf", "alternatives"]
    let alternativeKeys: Set<String> = ["label", "reference", "ranges"]
    for row in seedItems(seed) {
        #expect(Set(row.item.keys).isSubset(of: itemKeys), "\(row.section) \(row.key): \(row.item.keys)")
        for alternative in (row.item["alternatives"] as? [[String: Any]]) ?? [] {
            #expect(Set(alternative.keys).isSubset(of: alternativeKeys), "\(row.key) alternative")
        }
    }
}

@Test func `every seed item has a valid slot, reference, and ranges`() throws {
    let seed = try seedJSON()
    for row in seedItems(seed) {
        let slot = row.item["slot"] as? String ?? ""
        #expect(!slot.isEmpty, "\(row.key) has no slot")

        let reference = row.item["reference"] as? String ?? ""
        #expect(!reference.isEmpty, "\(row.key) \(slot) has an empty reference")

        let ranges = (row.item["ranges"] as? [[String: Any]]) ?? []
        if ranges.isEmpty {
            let id = "\(row.section)|\(row.key)|\(slot)|\(reference)"
            #expect(knownSeedItemsWithoutRanges.contains(id), "unexpected item without ranges: \(id)")
        }
        for range in ranges {
            let book = range["book"] as? String ?? ""
            #expect(usfmBooks.contains(book), "\(row.key) unknown book \(book)")
            let from = range["from"] as? String ?? ""
            let to = range["to"] as? String ?? ""
            let start = parseVerse(from)
            let end = parseVerse(to)
            #expect(start != nil, "\(row.key) bad from \(from)")
            #expect(end != nil, "\(row.key) bad to \(to)")
            if let start, let end {
                let ordered = (start.chapter, start.verse) <= (end.chapter, end.verse)
                #expect(ordered, "\(row.key) \(from) is after \(to)")
            }
        }
    }
    #expect(seedItems(seed).count == 3264)
}

@Test func `the seed keeps the Holy Saturday pairs and the Christmas Masses`() throws {
    let seed = try seedJSON()
    let sunday = try #require(seed["sunday"] as? [String: Any])

    // Seven Vigil readings, each followed by its psalm. A psalm also follows the second reading.
    let holySaturday = try #require(sunday["holy-saturday|A"] as? [[String: Any]])
    #expect(holySaturday.filter { $0["slot"] as? String == "first" }.count == 7)
    #expect(holySaturday.filter { $0["slot"] as? String == "psalm" }.count == 8)

    let christmas = try #require(sunday["nativity|B"] as? [[String: Any]])
    #expect(Set(christmas.compactMap { $0["set"] as? String }) == ["vigil", "night", "dawn", "day"])
}

@Test func `the Latin Rite date fixture matches the calendar`() throws {
    let file = try JSONDecoder().decode(DateFixtureFile.self, from: try fixtureData("calendar-conformance"))
    #expect(file.cases.count == 27)
    for testCase in file.cases {
        let date = try testCase.parsedDate()
        let country = try (testCase.country ?? []).map { try $0.celebration() }
        let day = LatinRiteCalendar.day(on: date, country: country)
        let context = "\(testCase.date) expected \(testCase.expect.id)"
        #expect(day.id == testCase.expect.id, Comment(rawValue: context))
        #expect(day.title == testCase.expect.title, Comment(rawValue: context))
        #expect(day.season.rawValue == testCase.expect.season, Comment(rawValue: context))
        #expect(day.readingKey == testCase.expect.readingKey, Comment(rawValue: context))
        #expect(day.fromCountryCalendar == testCase.expect.fromCountryCalendar, Comment(rawValue: context))
    }
}

@Test func `the placeholder calendar pack carries no production text`() throws {
    let object = try JSONSerialization.jsonObject(with: try fixtureData("calendar-test-en"))
    let root = try #require(object as? [String: Any])
    let data = try #require(root["data"] as? [String: Any])

    // Lectionary wording: every string under these keys must be a placeholder.
    let wordingKeys: Set<String> = ["text", "theme", "incipit", "refrain", "closing"]
    var checked = 0
    // Once inside a wording key, every string below it is wording (paragraphs, stanzas, lines).
    func walk(_ value: Any, inWording: Bool) {
        if let dict = value as? [String: Any] {
            for (k, v) in dict { walk(v, inWording: inWording || wordingKeys.contains(k)) }
        } else if let list = value as? [Any] {
            for element in list { walk(element, inWording: inWording) }
        } else if let text = value as? String, inWording {
            checked += 1
            #expect(text.hasPrefix("Test "), "production text: \(text.prefix(30))")
        }
    }
    walk(data, inWording: false)
    #expect(checked > 100)

    let formulas = try #require(data["formulas"] as? [String: Any])
    let acclamation = try #require(formulas["acclamation"] as? [String: [String]])
    #expect(acclamation["lent"]?.count == 4)
    for phrase in acclamation.values.flatMap({ $0 }) {
        #expect(phrase.hasPrefix("Test "), "production phrase: \(phrase)")
    }
    let titles = try #require(formulas["book_titles"] as? [String: String])
    for title in titles.values {
        #expect(title.hasPrefix("Test "), "production book title: \(title)")
    }
    let days = try #require(data["days"] as? [[String: Any]])
    for day in days {
        #expect((day["title"] as? String)?.hasPrefix("Test ") == true)
    }
}

// MARK: - Fixture decoding

private nonisolated struct DateFixtureFile: Decodable {
    var cases: [DateFixtureCase]
}

private nonisolated struct DateFixtureCase: Decodable {
    var date: String
    var country: [DateFixtureCountry]?
    var expect: DateFixtureExpect

    func parsedDate() throws -> CivilDate {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw DateFixtureError.badDate(date) }
        return CivilDate(year: parts[0], month: parts[1], day: parts[2])
    }
}

private nonisolated struct DateFixtureCountry: Decodable {
    var id: String
    var title: String
    var color: String
    var month: Int
    var day: Int
    var year: Int?

    func celebration() throws -> CountryCelebration {
        guard let color = LiturgicalColor(rawValue: color) else { throw DateFixtureError.badColor(color) }
        return CountryCelebration(id: id, title: title, color: color, month: month, day: day, year: year)
    }
}

private nonisolated struct DateFixtureExpect: Decodable {
    var id: String
    var title: String
    var season: String
    var readingKey: String
    var fromCountryCalendar: Bool
}

private nonisolated enum DateFixtureError: Error {
    case badDate(String)
    case badColor(String)
}
