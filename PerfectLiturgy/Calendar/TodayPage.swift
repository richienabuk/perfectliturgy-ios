import Foundation

/// What Today shows for one civil date. References only. No verse text.
nonisolated struct TodayReading: Equatable, Sendable, Identifiable {
    var label: String
    var reference: String
    /// When true, the row opens the Readings tab (multi-Mass days).
    var opensReadings: Bool

    var id: String { "\(label)|\(reference)|\(opensReadings)" }

    init(label: String, reference: String, opensReadings: Bool = false) {
        self.label = label
        self.reference = reference
        self.opensReadings = opensReadings
    }
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
        dayReadings: DayReadings,
        celebrationTitle: String,
        weekMark: String?
    ) -> TodayPage {
        let first = dayReadings.sets.first
        var rows: [TodayReading] = (first?.items ?? []).map { item in
            TodayReading(
                label: item.label,
                reference: item.forms.first?.reference ?? ""
            )
        }
        if dayReadings.sets.count > 1 {
            let count = dayReadings.sets.count
            rows.append(
                TodayReading(
                    label: "\(count) Masses. Open readings.",
                    reference: "",
                    opensReadings: true
                )
            )
        }
        return TodayPage(
            dateLine: dateLine(for: date),
            title: celebrationTitle,
            weekMark: weekMark,
            readings: rows
        )
    }

    /// Reference-only resolve for Today and Readings headers.
    static func load(
        date: CivilDate,
        calendar: CalendarOption,
        lectionary: Lectionary,
        bible: BibleChoice?,
        source: TextSource,
        fallback: Lectionary? = nil
    ) async -> TodayPage {
        let day = LatinRiteCalendar.day(on: date, country: calendar.celebrations)
        let resolved = await ReadingResolver.resolve(
            day: day,
            lectionary: lectionary,
            bible: bible,
            source: source,
            verses: EmptyVerseSource(),
            includeText: false,
            fallback: fallback
        )
        return page(
            for: date,
            dayReadings: resolved,
            celebrationTitle: day.title,
            weekMark: day.weekMark
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

/// Verse source that never returns text. Used for reference-only resolves.
struct EmptyVerseSource: VerseSource {
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
