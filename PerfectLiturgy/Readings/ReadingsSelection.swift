import Foundation

/// Selectable Readings dates: one month behind today through two months ahead, inclusive.
nonisolated enum ReadingsDateWindow {
    static let monthsBehind = 1
    static let monthsAhead = 2

    static func earliest(from today: CivilDate) -> CivilDate {
        today.adding(months: -monthsBehind)
    }

    static func latest(from today: CivilDate) -> CivilDate {
        today.adding(months: monthsAhead)
    }

    static func contains(_ date: CivilDate, today: CivilDate) -> Bool {
        date >= earliest(from: today) && date <= latest(from: today)
    }

    static func clamp(_ date: CivilDate, today: CivilDate) -> CivilDate {
        min(max(date, earliest(from: today)), latest(from: today))
    }
}

/// The day the Readings screen is showing, relative to the device's today.
nonisolated struct ReadingsCursor: Equatable, Sendable {
    var today: CivilDate
    var date: CivilDate

    init(today: CivilDate, date: CivilDate? = nil) {
        self.today = today
        self.date = ReadingsDateWindow.clamp(date ?? today, today: today)
    }

    var showsToday: Bool { date == today }
    var showsTomorrow: Bool { date == today.adding(days: 1) }
    var showsSunday: Bool { date == today.upcomingSunday }
    var showsPast: Bool { date < today }

    var canStepBack: Bool {
        ReadingsDateWindow.contains(date.adding(days: -1), today: today)
    }

    var canStepForward: Bool {
        ReadingsDateWindow.contains(date.adding(days: 1), today: today)
    }

    mutating func showToday() {
        date = today
    }

    mutating func showTomorrow() {
        date = ReadingsDateWindow.clamp(today.adding(days: 1), today: today)
    }

    mutating func showSunday() {
        date = ReadingsDateWindow.clamp(today.upcomingSunday, today: today)
    }

    mutating func step(by days: Int) {
        date = ReadingsDateWindow.clamp(date.adding(days: days), today: today)
    }

    mutating func choose(_ date: CivilDate) {
        self.date = ReadingsDateWindow.clamp(date, today: today)
    }

    /// Keeps a date the person picked. Follows the device when the screen was on today.
    mutating func noteToday(_ today: CivilDate) {
        let follow = date == self.today
        self.today = today
        if follow {
            date = today
        } else {
            date = ReadingsDateWindow.clamp(date, today: today)
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

    var firstDay: CivilDate { CivilDate(year: year, month: month, day: 1) }

    var lastDay: CivilDate {
        let count = CivilDate.calendar.range(of: .day, in: .month, for: firstDay.date)?.count ?? 1
        return CivilDate(year: year, month: month, day: count)
    }

    func advanced(by months: Int) -> MonthPage {
        let start = firstDay.date
        guard let next = CivilDate.calendar.date(byAdding: .month, value: months, to: start) else {
            return self
        }
        let date = CivilDate(next, calendar: CivilDate.calendar)
        return MonthPage(year: date.year, month: date.month, firstWeekday: firstWeekday)
    }

    /// True when this month contains at least one day inside the Readings window.
    func overlapsWindow(today: CivilDate) -> Bool {
        let earliest = ReadingsDateWindow.earliest(from: today)
        let latest = ReadingsDateWindow.latest(from: today)
        return lastDay >= earliest && firstDay <= latest
    }

    func canAdvance(by months: Int, today: CivilDate) -> Bool {
        advanced(by: months).overlapsWindow(today: today)
    }
}

/// A liturgical calendar the Readings screen can apply. Latin Rite is built in. Downloaded packs add the rest.
nonisolated struct CalendarOption: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var language: String
    var celebrations: [CountryCelebration]

    static let latinRite = CalendarOption(
        id: "latin-rite",
        title: "Latin Rite",
        language: "en",
        celebrations: []
    )
}

enum CalendarCatalog {
    static func list(installed: [CalendarOption]) -> [CalendarOption] {
        let extras = installed.filter { $0.id != CalendarOption.latinRite.id }
        return [CalendarOption.latinRite] + extras
    }

    static func selection(storedID: String, in options: [CalendarOption]) -> CalendarOption {
        options.first { $0.id == storedID } ?? .latinRite
    }

    /// Downloaded calendars whose pack id is installed and whose file passes `CalendarPackReader`.
    static func installed(ids: Set<String>, catalog: [PackRecord] = [], root: URL) -> [CalendarOption] {
        CalendarPackReader.installed(ids: ids, catalog: catalog, root: root)
    }
}

nonisolated struct BibleVersionChoice: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var language: String

    init(id: String, title: String, language: String = "en") {
        self.id = id
        self.title = title
        self.language = language
    }
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
