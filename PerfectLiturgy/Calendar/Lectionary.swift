import Foundation

/// Reference index bundled with the app. Verse text is not stored here.
/// A Bible version fills in later, one passage at a time, and only when every cited verse is on the device.
nonisolated struct LectionaryIndex: Equatable, Sendable {
    var sunday: [String: [ReadingCitation]]
    var feria: [String: [ReadingCitation]]
    var proper: [String: [ReadingCitation]]

    static let empty = LectionaryIndex(sunday: [:], feria: [:], proper: [:])

    func citations(for day: LiturgicalDay) -> [ReadingCitation] {
        let parts = day.readingKey.split(separator: "|").map(String.init)
        guard parts.count == 3 else {
            return day.slots.map { ReadingCitation(slot: $0, reference: "") }
        }
        let id = parts[0]
        let sundayCycle = parts[1]
        let weekdayCycle = parts[2]
        let stored = entries(id: id, sundayCycle: sundayCycle, weekdayCycle: weekdayCycle)
        let references = Dictionary(stored.map { ($0.slot, $0.reference) }, uniquingKeysWith: { first, _ in first })
        return day.slots.map { slot in
            ReadingCitation(slot: slot, reference: references[slot] ?? "")
        }
    }

    private func entries(id: String, sundayCycle: String, weekdayCycle: String) -> [ReadingCitation] {
        if id.hasPrefix("ot-feria") {
            return feria["\(id)|\(weekdayCycle)"] ?? []
        }
        if Self.properPrefixes.contains(where: { id.hasPrefix($0) }) {
            return proper[id] ?? []
        }
        if let sunday = sunday["\(id)|\(sundayCycle)"], !sunday.isEmpty {
            return sunday
        }
        return proper[id] ?? []
    }

    /// Seasonal ferias are keyed by celebration id alone. Ordinary Time weekdays use the feria table.
    private static let properPrefixes = [
        "lent-feria",
        "easter-feria",
        "advent-feria",
        "advent-december",
        "christmas-january",
        "christmas-octave",
        "after-epiphany",
        "easter-octave",
        "after-ash",
        "holy-week",
    ]
}

nonisolated enum Lectionary {
    static func load(bundle: Bundle = .main) -> LectionaryIndex {
        guard
            let url = bundle.url(forResource: "lectionary", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return .empty
        }
        return LectionaryIndex(
            sunday: file.sunday.mapValues(citations),
            feria: file.feria.mapValues(citations),
            proper: file.proper.mapValues(citations)
        )
    }

    private static func citations(_ entries: [File.Entry]) -> [ReadingCitation] {
        entries.map { ReadingCitation(slot: $0.slot, reference: $0.reference) }
    }

    private struct File: Decodable {
        var sunday: [String: [Entry]]
        var feria: [String: [Entry]]
        var proper: [String: [Entry]]

        struct Entry: Decodable {
            var slot: ReadingSlot
            var reference: String
        }
    }
}
