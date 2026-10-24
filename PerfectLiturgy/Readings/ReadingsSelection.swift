import Foundation

/// The day the Readings screen is showing, relative to the device's today.
nonisolated struct ReadingsCursor: Equatable, Sendable {
    var today: CivilDate
    var date: CivilDate

    init(today: CivilDate, date: CivilDate? = nil) {
        self.today = today
        self.date = date ?? today
    }

    var showsToday: Bool { date == today }
    var showsTomorrow: Bool { date == today.adding(days: 1) }
    var showsSunday: Bool { date == today.upcomingSunday }
    var showsPast: Bool { date < today }

    mutating func showToday() {
        date = today
    }

    mutating func showTomorrow() {
        date = today.adding(days: 1)
    }

    mutating func showSunday() {
        date = today.upcomingSunday
    }

    mutating func step(by days: Int) {
        date = date.adding(days: days)
    }

    mutating func choose(_ date: CivilDate) {
        self.date = date
    }

    /// Keeps a date the person picked. Follows the device when the screen was on today.
    mutating func noteToday(_ today: CivilDate) {
        let follow = date == self.today
        self.today = today
        if follow {
            date = today
        }
    }
}

/// One month for the date sheet. Nil cells pad the first and last week.
nonisolated struct MonthPage: Equatable, Sendable {
    var year: Int
    var month: Int
    var firstWeekday: Int

    static func containing(_ date: CivilDate, firstWeekday: Int = CivilDate.calendar.firstWeekday) -> MonthPage {
        MonthPage(year: date.year, month: date.month, firstWeekday: firstWeekday)
    }

    var title: String {
        let formatter = DateFormatter()
        formatter.calendar = CivilDate.calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: CivilDate(year: year, month: month, day: 1).date)
    }

    var weekdayLabels: [String] {
        let symbols = CivilDate.calendar.shortWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let start = (firstWeekday - 1 + 7) % 7
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    var cells: [CivilDate?] {
        let start = CivilDate(year: year, month: month, day: 1)
        let count = CivilDate.calendar.range(of: .day, in: .month, for: start.date)?.count ?? 0
        let leading = (start.weekday.rawValue - firstWeekday + 7) % 7
        var cells: [CivilDate?] = Array(repeating: nil, count: leading)
        for day in 1...count {
            cells.append(CivilDate(year: year, month: month, day: day))
        }
        while !cells.isEmpty, cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    func advanced(by months: Int) -> MonthPage {
        let start = CivilDate(year: year, month: month, day: 1).date
        guard let next = CivilDate.calendar.date(byAdding: .month, value: months, to: start) else {
            return self
        }
        let date = CivilDate(next, calendar: CivilDate.calendar)
        return MonthPage(year: date.year, month: date.month, firstWeekday: firstWeekday)
    }
}

/// A liturgical calendar the Readings screen can apply. Roman is built in. Country packs add the rest.
nonisolated struct CalendarOption: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var celebrations: [CountryCelebration]

    static let roman = CalendarOption(id: "roman", title: "Roman calendar", celebrations: [])
}

enum CalendarCatalog {
    static func list(installed: [CalendarOption]) -> [CalendarOption] {
        let extras = installed.filter { $0.id != CalendarOption.roman.id }
        return [CalendarOption.roman] + extras
    }

    static func selection(storedID: String, in options: [CalendarOption]) -> CalendarOption {
        options.first { $0.id == storedID } ?? .roman
    }

    /// Country calendars whose pack id is installed and whose file decodes.
    static func installed(ids: Set<String>, catalog: [PackRecord] = [], root: URL) -> [CalendarOption] {
        CountryCalendar.options(ids: ids, catalog: catalog, root: root)
    }
}

nonisolated struct BibleVersionChoice: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
}

/// What the Bible version row says, and whether a tap opens Downloads.
nonisolated struct BibleVersionStatus: Equatable, Sendable {
    var line: String
    var opensDownloads: Bool

    static func resolve(_ versions: [BibleVersionChoice], selectedID: String?) -> BibleVersionStatus {
        guard let version = versions.first(where: { $0.id == selectedID }) ?? versions.first else {
            return BibleVersionStatus(line: "None is available yet.", opensDownloads: true)
        }
        return BibleVersionStatus(line: version.title, opensDownloads: false)
    }
}
