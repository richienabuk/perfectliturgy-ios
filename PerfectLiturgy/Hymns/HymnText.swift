import Foundation

nonisolated enum HymnSectionKind: String, Equatable, Sendable {
    case verse
    case chorus
    case refrain
    case bridge
    case response
    case other

    init(raw: String) {
        self = HymnSectionKind(rawValue: raw.lowercased()) ?? .other
    }

    var repeatsWithVerses: Bool {
        switch self {
        case .chorus, .refrain, .response: true
        case .verse, .bridge, .other: false
        }
    }
}

nonisolated struct HymnSectionText: Equatable, Sendable {
    var type: HymnSectionKind
    var label: String
    var content: String
}

nonisolated enum HymnLyricCard: Equatable, Sendable {
    case stanza
    case refrain
}

nonisolated struct HymnLyricBlock: Equatable, Sendable, Identifiable {
    var id: Int
    var heading: String
    var content: String
    var card: HymnLyricCard
}

nonisolated enum AccentFold {
    /// Lowercase text with combining marks removed. Display strings stay as stored.
    static func fold(_ text: String) -> String {
        text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .lowercased()
    }
}

nonisolated enum HymnLyrics {
    /// Screen order. Four or more verses show the first refrain, chorus, or response
    /// after the midpoint verse and at the end. A copy already in that place is kept.
    /// The stored sections are not changed.
    static func blocks(sections: [HymnSectionText], lyrics: String) -> [HymnLyricBlock] {
        let stored = sections.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !stored.isEmpty else {
            let trimmed = lyrics.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            return [HymnLyricBlock(id: 0, heading: "STANZA 1", content: trimmed, card: .stanza)]
        }

        let verseCount = stored.filter { $0.type == .verse }.count
        let repeated = stored.first { $0.type.repeatsWithVerses }
        let repeats = verseCount >= 4 && repeated != nil
        let midpoint = verseCount / 2

        var blocks: [HymnLyricBlock] = []
        var verseIndex = 0
        var didInsertMidpoint = false
        for (index, section) in stored.enumerated() {
            if section.type == .verse {
                verseIndex += 1
            }
            blocks.append(block(for: section, verseIndex: verseIndex, id: blocks.count))
            if repeats, verseIndex == midpoint, section.type == .verse, !didInsertMidpoint, let repeated {
                let next = index + 1 < stored.count ? stored[index + 1] : nil
                if next?.type.repeatsWithVerses != true {
                    blocks.append(block(for: repeated, verseIndex: 0, id: blocks.count))
                }
                didInsertMidpoint = true
            }
        }
        if repeats, let repeated, !isRepeat(blocks.last, of: repeated) {
            blocks.append(block(for: repeated, verseIndex: 0, id: blocks.count))
        }
        return blocks
    }

    private static func isRepeat(_ block: HymnLyricBlock?, of section: HymnSectionText) -> Bool {
        block?.card == .refrain && block?.content == section.content
    }

    private static func block(for section: HymnSectionText, verseIndex: Int, id: Int) -> HymnLyricBlock {
        let heading: String
        let card: HymnLyricCard
        switch section.type {
        case .verse:
            heading = "STANZA \(verseIndex)"
            card = .stanza
        case .chorus, .refrain:
            heading = "CHORUS / REFRAIN"
            card = .refrain
        case .response:
            heading = "RESPONSE"
            card = .refrain
        case .bridge:
            heading = "BRIDGE"
            card = .stanza
        case .other:
            let label = section.label.trimmingCharacters(in: .whitespacesAndNewlines)
            heading = label.isEmpty ? "OTHER" : label.uppercased()
            card = .stanza
        }
        return HymnLyricBlock(id: id, heading: heading, content: section.content, card: card)
    }
}

nonisolated struct HymnSummary: Equatable, Sendable, Identifiable {
    var id: String
    var language: String
    var hymnNumber: Int
    var title: String
    var firstLine: String
    var searchKey: String
    var sectionText: String
    var seasons: [String]
    var massParts: [String]
    var topics: [String]
}

/// A hymn copied out of the store. Screens keep this, so removing the pack does not read a deleted row.
struct HymnPage: Equatable, Identifiable {
    var id: String
    var language: String
    var hymnNumber: Int
    var title: String
    var firstLine: String
    var backgroundNotes: String?
    var catalogueLine: String
    var wideMeta: String
    var lyricsStatus: String
    var performanceLine: String?
    var blocks: [HymnLyricBlock]
    var shareText: String
    var audioURLs: [String]
    var videoURLs: [String]
    var sheetMusicURLs: [String]
}

nonisolated struct HymnFilter: Equatable, Sendable {
    var text: String = ""
    var language: String?
    var season: String?
    var massPart: String?

    static let pageSize = 80
    static let seasons = ["advent", "christmas", "lent", "easter", "ordinary_time"]
    static let massParts = ["entrance", "offertory", "communion", "recessional"]
}

nonisolated enum HymnSearch {
    static func makeKey(title: String, firstLine: String, lyrics: String) -> String {
        AccentFold.fold([title, firstLine, lyrics].joined(separator: "\n"))
    }

    static func matches(_ hymn: HymnSummary, filter: HymnFilter) -> Bool {
        if let language = filter.language, !language.isEmpty, hymn.language != language {
            return false
        }
        if let season = filter.season, !seasonMatches(stored: hymn.seasons, filter: season) {
            return false
        }
        if let part = filter.massPart, !partMatches(stored: hymn.massParts, filter: part) {
            return false
        }
        return textMatches(hymn, query: filter.text)
    }

    static func seasonMatches(stored: [String], filter: String) -> Bool {
        let accepted: Set<String> = filter == "easter" ? ["easter", "easter_pentecost"] : [filter]
        return stored.contains { accepted.contains($0) }
    }

    static func partMatches(stored: [String], filter: String) -> Bool {
        let accepted: Set<String> = filter == "offertory" ? ["offertory", "offering"] : [filter]
        return stored.contains { accepted.contains($0) }
    }

    static func textMatches(_ hymn: HymnSummary, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if trimmed.allSatisfy(\.isNumber) {
            return hymn.hymnNumber == Int(trimmed) || hymn.id.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        if hymn.id.compare(trimmed, options: .caseInsensitive) == .orderedSame {
            return true
        }
        let folded = AccentFold.fold(trimmed)
        let words = folded.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }
        let haystack = hymn.searchKey + "\n" + AccentFold.fold(hymn.sectionText)
        return words.allSatisfy { haystack.contains($0) }
    }
}

nonisolated enum HymnLanguage {
    static func ordered(_ codes: [String]) -> [String] {
        let preferred = ["en", "la"]
        return Array(Set(codes)).sorted { lhs, rhs in
            let left = preferred.firstIndex(of: lhs) ?? preferred.count
            let right = preferred.firstIndex(of: rhs) ?? preferred.count
            if left != right { return left < right }
            return name(for: lhs) < name(for: rhs)
        }
    }

    static func name(for code: String, in packs: [PackRecord] = []) -> String {
        if let pack = hymnPack(code, in: packs) {
            if let languageName = trimmed(pack.languageName) { return languageName }
            if let fromTitle = language(inCatalogue: pack.displayName) { return fromTitle }
        }
        switch code {
        case "en": return "English"
        case "la": return "Latin"
        default: return code
        }
    }

    static func catalogueName(for code: String, in packs: [PackRecord] = []) -> String {
        if let pack = hymnPack(code, in: packs) {
            let title = pack.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
        }
        return "\(name(for: code, in: packs)) Hymns"
    }

    private static func hymnPack(_ code: String, in packs: [PackRecord]) -> PackRecord? {
        packs.first { $0.type == "hymns" && $0.language == code }
    }

    /// `Efik Hymns` yields `Efik` when the catalog has no separate language name.
    private static func language(inCatalogue title: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.hasSuffix(" Hymns") else { return nil }
        let name = String(trimmedTitle.dropLast(" Hymns".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum HymnLabels {
    static func token(_ token: String) -> String {
        switch token {
        case "advent": "Advent"
        case "christmas": "Christmas"
        case "lent": "Lent"
        case "easter", "easter_pentecost": "Easter"
        case "ordinary_time": "Ordinary Time"
        case "entrance": "Entrance"
        case "offertory", "offering": "Offertory"
        case "communion": "Communion"
        case "recessional": "Recessional"
        case "incensation": "Incensation"
        case "pre_homily": "Before the homily"
        case "general": "General"
        case "our_lord": "Our Lord"
        case "our_lady": "Our Lady"
        case "hymns_for_the_dead": "Hymns for the dead"
        default:
            token.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func catalogueLine(language: String, seasons: [String], massParts: [String], topics: [String], catalogues: [PackRecord] = []) -> String {
        var parts = [HymnLanguage.catalogueName(for: language, in: catalogues)]
        parts.append(contentsOf: seasons.map(token))
        parts.append(contentsOf: massParts.map(token))
        parts.append(contentsOf: topics.map(token))
        return parts.joined(separator: " · ")
    }

    /// List subtitle: the catalogue name, then the Mass parts. Seasons stand in when a hymn has no part.
    static func rowLine(language: String, seasons: [String], massParts: [String], catalogues: [PackRecord] = []) -> String {
        var parts = [HymnLanguage.catalogueName(for: language, in: catalogues)]
        let detail = massParts.isEmpty ? seasons : massParts
        parts.append(contentsOf: detail.map(token))
        return parts.joined(separator: " · ")
    }

    /// Detail line under the title on a wide screen. The language name is already the eyebrow.
    static func detailMeta(seasons: [String], massParts: [String], topics: [String]) -> String {
        (seasons + massParts + topics).map(token).joined(separator: " · ")
    }

    static func matchCount(_ count: Int) -> String {
        switch count {
        case 0: "No hymns"
        case 1: "1 hymn"
        default: "\(count) hymns"
        }
    }

    static func resultCount(_ count: Int) -> String {
        switch count {
        case 0: "No results"
        case 1: "1 result"
        default: "\(count) results"
        }
    }

    static func itemCount(_ count: Int) -> String {
        switch count {
        case 0: "No items"
        case 1: "1 item"
        default: "\(count) items"
        }
    }
}

nonisolated enum HymnShareText {
    static func make(
        language: String,
        number: Int,
        title: String,
        seasons: [String],
        massParts: [String],
        topics: [String],
        sections: [HymnSectionText],
        lyrics: String,
        tuneName: String?,
        musicalKey: String?
    ) -> String {
        var lines = [
            HymnLabels.catalogueLine(language: language, seasons: seasons, massParts: massParts, topics: topics),
            String(number),
            title,
            "",
        ]
        if sections.isEmpty {
            if let only = HymnLyrics.blocks(sections: [], lyrics: lyrics).first {
                lines.append(only.heading)
                lines.append(only.content)
                lines.append("")
            }
        } else {
            var verseIndex = 0
            for section in sections {
                if section.type == .verse { verseIndex += 1 }
                lines.append(heading(for: section, verseIndex: verseIndex))
                lines.append(section.content.trimmingCharacters(in: .whitespacesAndNewlines))
                lines.append("")
            }
        }
        if let tuneName, !tuneName.isEmpty { lines.append("Tune \(tuneName)") }
        if let musicalKey, !musicalKey.isEmpty { lines.append("Key \(musicalKey)") }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func heading(for section: HymnSectionText, verseIndex: Int = 0) -> String {
        switch section.type {
        case .verse: "STANZA \(max(verseIndex, 1))"
        case .chorus, .refrain: "CHORUS / REFRAIN"
        case .response: "RESPONSE"
        case .bridge: "BRIDGE"
        case .other:
            section.label.isEmpty ? "OTHER" : section.label.uppercased()
        }
    }
}

extension HymnRecord {
    var orderedSections: [HymnSectionRecord] {
        sections.sorted { $0.position < $1.position }
    }

    var sectionTexts: [HymnSectionText] {
        orderedSections.map {
            HymnSectionText(type: HymnSectionKind(raw: $0.typeRaw), label: $0.label, content: $0.content)
        }
    }

    var summary: HymnSummary {
        HymnSummary(
            id: id,
            language: language,
            hymnNumber: hymnNumber,
            title: title,
            firstLine: firstLine,
            searchKey: searchKey,
            sectionText: orderedSections.map(\.content).joined(separator: "\n"),
            seasons: seasons,
            massParts: massParts,
            topics: topics
        )
    }

    var page: HymnPage {
        let texts = sectionTexts
        let hasMedia = !audioURLs.isEmpty || !videoURLs.isEmpty || !sheetMusicURLs.isEmpty
        var performance: [String] = []
        if let tune = tuneName, !tune.isEmpty { performance.append("Tune \(tune)") }
        if let key = musicalKey, !key.isEmpty { performance.append("Key \(key)") }
        if let authors, !authors.isEmpty { performance.append(authors) }
        let meta = HymnLabels.detailMeta(seasons: seasons, massParts: massParts, topics: topics)
        let catalogue = HymnLabels.catalogueLine(
            language: language,
            seasons: seasons,
            massParts: massParts,
            topics: topics
        )
        return HymnPage(
            id: id,
            language: language,
            hymnNumber: hymnNumber,
            title: title,
            firstLine: firstLine,
            backgroundNotes: backgroundNotes,
            catalogueLine: catalogue,
            wideMeta: meta.isEmpty ? catalogue : meta,
            lyricsStatus: hasMedia ? "Lyrics · Recordings" : "Lyrics · No recordings",
            performanceLine: performance.isEmpty ? nil : performance.joined(separator: " · "),
            blocks: HymnLyrics.blocks(sections: texts, lyrics: lyrics),
            shareText: HymnShareText.make(
                language: language,
                number: hymnNumber,
                title: title,
                seasons: seasons,
                massParts: massParts,
                topics: topics,
                sections: texts,
                lyrics: lyrics,
                tuneName: tuneName,
                musicalKey: musicalKey
            ),
            audioURLs: audioURLs,
            videoURLs: videoURLs,
            sheetMusicURLs: sheetMusicURLs
        )
    }
}
