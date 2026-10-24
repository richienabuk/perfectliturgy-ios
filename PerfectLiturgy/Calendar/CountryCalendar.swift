import Foundation

/// A downloaded country calendar. The title comes from the catalog display name.
enum CountryCalendar {
    static func celebrations(in data: Data) -> [CountryCelebration]? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let envelope = try? decoder.decode(CountryCalendarBody.self, from: data) else { return nil }
        return envelope.days.compactMap { day in
            guard let color = LiturgicalColor(rawValue: day.color.lowercased()) else { return nil }
            guard (1...12).contains(day.month), (1...31).contains(day.day) else { return nil }
            let title = day.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = day.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !id.isEmpty else { return nil }
            return CountryCelebration(id: id, title: title, color: color, month: day.month, day: day.day, year: day.year)
        }
    }

    static func options(ids: Set<String>, catalog: [PackRecord], root: URL) -> [CalendarOption] {
        let titles = Dictionary(catalog.map { ($0.packId, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        return ids
            .filter { $0.hasPrefix("calendar-") }
            .sorted()
            .compactMap { id in
                let url = PackFiles.file(for: id, root: root)
                guard let data = try? Data(contentsOf: url), let days = celebrations(in: data) else { return nil }
                return CalendarOption(id: id, title: titles[id] ?? id, celebrations: days)
            }
    }
}

private struct CountryCalendarBody: Decodable {
    var days: [CountryCalendarDay]

    private enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([CountryCalendarDay].self, forKey: .data) {
            days = list
            return
        }
        let wrapped = try container.decode(CountryCalendarWrapped.self, forKey: .data)
        days = wrapped.celebrations ?? wrapped.days ?? []
    }
}

private struct CountryCalendarWrapped: Decodable {
    var celebrations: [CountryCalendarDay]?
    var days: [CountryCalendarDay]?
}

private struct CountryCalendarDay: Decodable {
    var id: String
    var title: String
    var color: String
    var month: Int
    var day: Int
    var year: Int?
}
