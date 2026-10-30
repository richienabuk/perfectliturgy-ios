import Foundation

/// Decodes and validates a `calendar-{id}` pack (§5). Days-only files fail.
enum CalendarPackReader {
    enum Failure: Error, Equatable {
        case invalid
        case badRange
    }

    /// Pack envelope only. Rejects the seed shape and the old days-only shape.
    nonisolated static func decode(_ data: Data) throws -> Lectionary {
        let lectionary = try LectionaryStore.decodePack(data)
        try validate(lectionary)
        return lectionary
    }

    static func option(id: String, title: String, data: Data) throws -> CalendarOption {
        let lectionary = try decode(data)
        return CalendarOption(
            id: id,
            title: title.isEmpty ? lectionary.displayName : title,
            language: lectionary.language,
            celebrations: lectionary.days
        )
    }

    /// Drops installed `calendar-` ids whose files fail to decode (including the old days-only shape).
    static func reconcileInstalled(
        packs: InstalledPacks,
        defaults: UserDefaults,
        root: URL,
        catalog: [PackRecord] = []
    ) {
        let titles = Dictionary(catalog.map { ($0.packId, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        for id in packs.ids.filter({ $0.hasPrefix("calendar-") }) {
            let url = PackFiles.file(for: id, root: root)
            guard
                let data = try? Data(contentsOf: url),
                (try? option(id: id, title: titles[id] ?? id, data: data)) != nil
            else {
                packs.remove(id)
                PackFiles.clearRevision(for: id, defaults: defaults)
                continue
            }
        }
    }

    static func installed(ids: Set<String>, catalog: [PackRecord] = [], root: URL) -> [CalendarOption] {
        let titles = Dictionary(catalog.map { ($0.packId, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        return ids
            .filter { $0.hasPrefix("calendar-") }
            .sorted()
            .compactMap { id in
                let url = PackFiles.file(for: id, root: root)
                guard let data = try? Data(contentsOf: url) else { return nil }
                // Install already validated ranges. Skip that scan on every Readings/Today refresh.
                guard let lectionary = try? LectionaryStore.decodePack(data) else { return nil }
                return CalendarOption(
                    id: id,
                    title: titles[id] ?? lectionary.displayName,
                    language: lectionary.language,
                    celebrations: lectionary.days
                )
            }
    }

    // MARK: - Validation

    nonisolated private static func validate(_ lectionary: Lectionary) throws {
        guard !lectionary.id.isEmpty, !lectionary.language.isEmpty else { throw Failure.invalid }
        for table in [lectionary.sunday, lectionary.feria, lectionary.proper] {
            for items in table.values {
                for item in items {
                    try validate(ranges: item.ranges)
                    for alternative in item.alternatives {
                        try validate(ranges: alternative.ranges)
                    }
                }
            }
        }
    }

    nonisolated private static func validate(ranges: [VerseRange]) throws {
        for range in ranges {
            guard !range.book.isEmpty else { throw Failure.badRange }
            guard let from = point(range.from), let to = point(range.to) else { throw Failure.badRange }
            if from.chapter > to.chapter { throw Failure.badRange }
            if from.chapter == to.chapter, from.verse > to.verse { throw Failure.badRange }
        }
    }

    /// `chapter:verse` with an optional part letter. Parts are ignored for order checks.
    nonisolated private static func point(_ text: String) -> (chapter: Int, verse: Int)? {
        let pattern = #/^([1-9]\d*):([1-9]\d*)[a-z]?$/#
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        guard let chapter = Int(match.1), let verse = Int(match.2) else { return nil }
        return (chapter, verse)
    }
}
