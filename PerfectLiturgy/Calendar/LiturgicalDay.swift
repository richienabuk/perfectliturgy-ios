import Foundation

/// A civil year, month, and day. Liturgical dates do not depend on the clock time.
nonisolated struct CivilDate: Hashable, Sendable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 1
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    var weekday: Weekday {
        let raw = Self.calendar.component(.weekday, from: date)
        return Weekday(rawValue: raw) ?? .sunday
    }

    static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    func adding(days: Int) -> CivilDate {
        let next = Self.calendar.date(byAdding: .day, value: days, to: date) ?? date
        return CivilDate(next, calendar: Self.calendar)
    }

    func days(until other: CivilDate) -> Int {
        Self.calendar.dateComponents([.day], from: date, to: other.date).day ?? 0
    }

    /// The Sunday of this liturgical week. A Sunday returns itself.
    var sundayOnOrBefore: CivilDate {
        adding(days: 1 - weekday.rawValue)
    }
}

nonisolated enum Weekday: Int, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var name: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    var slug: String {
        switch self {
        case .sunday: "sunday"
        case .monday: "monday"
        case .tuesday: "tuesday"
        case .wednesday: "wednesday"
        case .thursday: "thursday"
        case .friday: "friday"
        case .saturday: "saturday"
        }
    }
}

nonisolated enum LiturgicalColor: String, Equatable, Sendable {
    case green
    case white
    case red
    case purple
}

nonisolated enum LiturgicalSeason: String, Equatable, Sendable {
    case advent
    case christmas
    case lent
    case easter
    case ordinary
}

nonisolated enum LiturgicalRank: Int, Comparable, Sendable {
    case feria = 0
    case memorial = 1
    case seasonalWeekday = 2
    case requiredMemorial = 3
    case feast = 4
    case sunday = 5
    case feastOfTheLord = 6
    case solemnity = 7
    case privileged = 8
    case triduum = 9

    static func < (lhs: LiturgicalRank, rhs: LiturgicalRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Year A, B, or C. 2026 is A and 2027 is B, so the remainder of the liturgical year maps 1, 2, 0.
nonisolated enum SundayCycle: String, Sendable {
    case A
    case B
    case C

    init(liturgicalYear: Int) {
        switch liturgicalYear % 3 {
        case 1: self = .A
        case 2: self = .B
        default: self = .C
        }
    }
}

/// An even liturgical year is II. An odd year is I.
nonisolated enum WeekdayCycle: String, Sendable {
    case I
    case II

    init(liturgicalYear: Int) {
        self = liturgicalYear.isMultiple(of: 2) ? .II : .I
    }
}

nonisolated enum ReadingSlot: String, Codable, CaseIterable, Sendable, Identifiable {
    case first
    case psalm
    case second
    case acclamation
    case gospel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .first: "First reading"
        case .psalm: "Responsorial psalm"
        case .second: "Second reading"
        case .acclamation: "Gospel acclamation"
        case .gospel: "Gospel"
        }
    }
}

nonisolated struct ReadingCitation: Equatable, Sendable, Identifiable {
    var slot: ReadingSlot
    var reference: String

    var id: String { slot.rawValue }
}

/// One calculated day. `readingKey` keeps the Roman celebration so a country day does not change the citations.
nonisolated struct LiturgicalDay: Equatable, Sendable {
    var id: String
    var title: String
    var color: LiturgicalColor
    var season: LiturgicalSeason
    var rank: LiturgicalRank
    var weekMark: String?
    var fromCountryCalendar: Bool
    var readingKey: String
    var slots: [ReadingSlot]

    var hasSecondReading: Bool {
        slots.contains(.second)
    }
}

/// A country calendar entry. A nil year matches the month and day every year. A year matches one full date.
nonisolated struct CountryCelebration: Equatable, Sendable {
    var id: String
    var title: String
    var color: LiturgicalColor
    var month: Int
    var day: Int
    var year: Int?

    init(id: String, title: String, color: LiturgicalColor, month: Int, day: Int, year: Int? = nil) {
        self.id = id
        self.title = title
        self.color = color
        self.month = month
        self.day = day
        self.year = year
    }

    func matches(_ date: CivilDate) -> Bool {
        guard month == date.month, day == date.day else { return false }
        guard let year else { return true }
        return year == date.year
    }
}
