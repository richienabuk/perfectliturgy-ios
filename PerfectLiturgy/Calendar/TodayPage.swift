import Foundation

/// What Today shows for one civil date. References only. No verse text.
nonisolated struct TodayReading: Equatable, Sendable, Identifiable {
    var label: String
    var reference: String

    var id: String { label }
}

nonisolated struct TodayPage: Equatable, Sendable {
    var dateLine: String
    var title: String
    var weekMark: String?
    var readings: [TodayReading]
}

nonisolated enum TodayPageBuilder {
    static func page(
        for date: CivilDate,
        country: [CountryCelebration] = [],
        lectionary: LectionaryIndex = .empty
    ) -> TodayPage {
        let day = RomanCalendar.day(on: date, country: country)
        let citations = lectionary.citations(for: day)
        return TodayPage(
            dateLine: dateLine(for: date),
            title: day.title,
            weekMark: day.weekMark,
            readings: citations.map { TodayReading(label: $0.slot.label, reference: $0.reference) }
        )
    }

    static func dateLine(for date: CivilDate) -> String {
        formatted(date, "EEEE '·' d MMMM yyyy")
    }

    /// The date on the Readings card, as in "Sunday, 25 October 2026".
    static func spokenDate(for date: CivilDate) -> String {
        formatted(date, "EEEE, d MMMM yyyy")
    }

    private static func formatted(_ date: CivilDate, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = CivilDate.calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter.string(from: date.date)
    }
}
