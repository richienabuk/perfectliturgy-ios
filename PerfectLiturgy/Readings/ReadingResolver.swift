import Foundation

/// Builds `DayReadings` from a day, lectionary, Bible choice, and verse source (§8.4, §9).
/// Runs off the main actor so date changes do not freeze the Readings screen.
nonisolated enum ReadingResolver {
    @concurrent
    static func resolve(
        day: LiturgicalDay,
        lectionary: Lectionary,
        bible: BibleChoice?,
        source: TextSource,
        verses: some VerseSource,
        includeText: Bool = true,
        /// Latin Rite seed. Used when the active calendar has no items for the day and the languages match.
        fallback: Lectionary? = nil
    ) async -> DayReadings {
        let items = items(for: day, lectionary: lectionary, fallback: fallback)
        guard !items.isEmpty else {
            return DayReadings(key: day.readingKey, sets: [])
        }

        let hideIncipit: Bool = {
            guard let bible else { return false }
            return bible.language != lectionary.language
        }()

        var position = 0
        var sets: [ReadingSet] = []
        for group in grouped(items) {
            var resolved: [ReadingItem] = []
            for item in group.items {
                let reading = await resolveItem(
                    item,
                    position: position,
                    day: day,
                    lectionary: lectionary,
                    bible: bible,
                    source: source,
                    verses: verses,
                    includeText: includeText,
                    hideIncipit: hideIncipit
                )
                resolved.append(reading)
                position += 1
            }
            let label = group.id.flatMap { lectionary.formulas.sets[$0] }
            sets.append(ReadingSet(id: group.id, label: label, items: resolved))
        }
        return DayReadings(key: day.readingKey, sets: sets)
    }

    /// Active calendar first. Fall back to the Latin Rite seed when languages match (§8.4).
    static func items(
        for day: LiturgicalDay,
        lectionary: Lectionary,
        fallback: Lectionary?
    ) -> [LectionaryItem] {
        let primary = LectionaryKey.items(for: day, in: lectionary)
        if !primary.isEmpty { return primary }
        guard let fallback else { return [] }
        guard fallback.language == lectionary.language else { return [] }
        guard lectionary.id != fallback.id else { return [] }
        return LectionaryKey.items(for: day, in: fallback)
    }

    // MARK: - Item

    private static func resolveItem(
        _ item: LectionaryItem,
        position: Int,
        day: LiturgicalDay,
        lectionary: Lectionary,
        bible: BibleChoice?,
        source: TextSource,
        verses: some VerseSource,
        includeText: Bool,
        hideIncipit: Bool
    ) async -> ReadingItem {
        let slotFormula = lectionary.formulas.slots[item.slot]
        let label = item.label ?? slotFormula?.label ?? item.slot
        let closing = item.closing ?? slotFormula?.closing
        let phrases = acclamationPhrases(for: item, day: day, formulas: lectionary.formulas)

        let isAcclamation = item.slot == "acclamation"
        var forms: [ReadingForm] = [
            await form(
                label: nil,
                reference: item.reference,
                ranges: item.ranges,
                theme: isAcclamation ? nil : item.theme,
                incipit: isAcclamation ? nil : item.incipit,
                refrain: item.refrain,
                refrainRef: item.refrainRef,
                text: item.text,
                verseOverrides: item.verseOverrides,
                lectionary: lectionary,
                bible: bible,
                source: source,
                verses: verses,
                includeText: includeText,
                hideIncipit: hideIncipit || isAcclamation,
                isPsalm: item.slot == "psalm",
                omitBookTitle: isAcclamation
            )
        ]
        for alternative in item.alternatives {
            forms.append(
                await form(
                    label: alternative.label,
                    reference: alternative.reference,
                    ranges: alternative.ranges,
                    theme: isAcclamation ? nil : (alternative.theme ?? item.theme),
                    incipit: isAcclamation ? nil : (alternative.incipit ?? item.incipit),
                    refrain: alternative.refrain ?? item.refrain,
                    refrainRef: alternative.refrainRef ?? item.refrainRef,
                    text: alternative.text ?? item.text,
                    verseOverrides: alternative.verseOverrides.isEmpty
                        ? item.verseOverrides
                        : alternative.verseOverrides,
                    lectionary: lectionary,
                    bible: bible,
                    source: source,
                    verses: verses,
                    includeText: includeText,
                    hideIncipit: hideIncipit || isAcclamation,
                    isPsalm: item.slot == "psalm",
                    omitBookTitle: isAcclamation
                )
            )
        }

        return ReadingItem(
            id: position,
            slot: item.slot,
            label: label,
            forms: forms,
            refrain: item.refrain,
            refrainRef: item.refrainRef,
            acclamationPhrases: phrases,
            selectedAcclamationIndex: 0,
            closing: closing,
            cf: item.cf
        )
    }

    private static func form(
        label: String?,
        reference: String?,
        ranges: [VerseRange],
        theme: String?,
        incipit: String?,
        refrain: String?,
        refrainRef: String?,
        text: LectionaryBody?,
        verseOverrides: [VerseOverride],
        lectionary: Lectionary,
        bible: BibleChoice?,
        source: TextSource,
        verses: some VerseSource,
        includeText: Bool,
        hideIncipit: Bool,
        isPsalm: Bool,
        omitBookTitle: Bool = false
    ) async -> ReadingForm {
        let bookID = ranges.first?.book
        let bookTitle = omitBookTitle ? nil : bookID.flatMap { lectionary.formulas.bookTitles[$0] }
        let shownIncipit = hideIncipit ? nil : incipit
        let body: ReadingBody
        if includeText {
            body = await bodyText(
                ranges: ranges,
                text: text,
                verseOverrides: verseOverrides,
                bible: bible,
                source: source,
                verses: verses,
                isPsalm: isPsalm
            )
        } else if isPsalm {
            body = .psalm(stanzas: [])
        } else {
            body = .passage(verses: [], fullVerseShown: false)
        }
        return ReadingForm(
            label: label,
            reference: reference ?? "",
            bookTitle: bookTitle,
            theme: theme,
            incipit: shownIncipit,
            refrain: refrain,
            refrainRef: refrainRef,
            body: body
        )
    }

    // MARK: - Body

    private static func bodyText(
        ranges: [VerseRange],
        text: LectionaryBody?,
        verseOverrides: [VerseOverride],
        bible: BibleChoice?,
        source: TextSource,
        verses: some VerseSource,
        isPsalm: Bool
    ) async -> ReadingBody {
        // Full calendar body wins when the pack provides it.
        if let text {
            switch text {
            case .paragraphs(let paragraphs):
                return .lectionary(paragraphs: paragraphs, stanzas: [])
            case .stanzas(let stanzas):
                return .lectionary(paragraphs: [], stanzas: stanzas)
            }
        }

        let versionID: String?
        switch source {
        case .bible(let id):
            versionID = id.isEmpty ? nil : id
        }
        guard let versionID else {
            return .unavailable(.noVersion)
        }
        guard let bible else {
            return .unavailable(.noVersion)
        }
        guard bible.id == versionID else {
            return .unavailable(.notDownloaded)
        }

        if ranges.isEmpty {
            return isPsalm ? .psalm(stanzas: []) : .passage(verses: [], fullVerseShown: false)
        }

        let overrideIndex = OverrideIndex(verseOverrides)
        if isPsalm {
            return await psalmBody(
                ranges: ranges,
                versionID: versionID,
                verses: verses,
                overrides: overrideIndex
            )
        }
        return await passageBody(
            ranges: ranges,
            versionID: versionID,
            verses: verses,
            overrides: overrideIndex
        )
    }

    private static func passageBody(
        ranges: [VerseRange],
        versionID: String,
        verses: some VerseSource,
        overrides: OverrideIndex
    ) async -> ReadingBody {
        var collected: [VerseText] = []
        var fullVerseShown = false
        var sawAny = false
        for range in ranges {
            guard let from = Point.parse(range.from), let to = Point.parse(range.to) else {
                return .unavailable(.missingVerses)
            }
            let rows = await verses.verses(
                version: versionID,
                book: range.book,
                fromChapter: from.chapter,
                fromVerse: from.verse,
                toChapter: to.chapter,
                toVerse: to.verse
            )
            if rows.isEmpty {
                return .unavailable(.missingVerses)
            }
            sawAny = true
            let firstKey = VerseKey(chapter: from.chapter, verse: from.verse)
            let lastKey = VerseKey(chapter: to.chapter, verse: to.verse)
            for row in rows {
                let key = VerseKey(chapter: row.chapter, verse: row.verse)
                let fromPart = key == firstKey ? from.part : nil
                let toPart = key == lastKey ? to.part : nil
                let sliced = slice(row, fromPart: fromPart, toPart: toPart)
                if sliced.fullVerseShown { fullVerseShown = true }
                collected.append(applyOverride(sliced.verse, book: range.book, overrides: overrides))
            }
        }
        guard sawAny else { return .unavailable(.missingVerses) }
        return .passage(verses: collected, fullVerseShown: fullVerseShown)
    }

    private static func psalmBody(
        ranges: [VerseRange],
        versionID: String,
        verses: some VerseSource,
        overrides: OverrideIndex
    ) async -> ReadingBody {
        var stanzas: [[VerseText]] = []
        for stanzaRanges in stanzaGroups(ranges) {
            var stanza: [VerseText] = []
            for range in stanzaRanges {
                guard let from = Point.parse(range.from), let to = Point.parse(range.to) else {
                    return .unavailable(.missingVerses)
                }
                let rows = await verses.verses(
                    version: versionID,
                    book: range.book,
                    fromChapter: from.chapter,
                    fromVerse: from.verse,
                    toChapter: to.chapter,
                    toVerse: to.verse
                )
                if rows.isEmpty {
                    return .unavailable(.missingVerses)
                }
                let firstKey = VerseKey(chapter: from.chapter, verse: from.verse)
                let lastKey = VerseKey(chapter: to.chapter, verse: to.verse)
                for row in rows {
                    let key = VerseKey(chapter: row.chapter, verse: row.verse)
                    let fromPart = key == firstKey ? from.part : nil
                    let toPart = key == lastKey ? to.part : nil
                    let verse = slice(row, fromPart: fromPart, toPart: toPart).verse
                    stanza.append(applyOverride(verse, book: range.book, overrides: overrides))
                }
            }
            stanzas.append(stanza)
        }
        return .psalm(stanzas: stanzas)
    }

    /// Replaces a loaded Bible verse when the calendar supplies an override for it.
    private static func applyOverride(
        _ verse: VerseText,
        book: String,
        overrides: OverrideIndex
    ) -> VerseText {
        guard let text = overrides.text(book: book, chapter: verse.chapter, verse: verse.verse) else {
            return verse
        }
        return VerseText(
            chapter: verse.chapter,
            verse: verse.verse,
            spans: [ReadingSpan(text: text, style: nil)]
        )
    }

    /// Each range starts a stanza unless `continues` is true, then it joins the previous.
    private static func stanzaGroups(_ ranges: [VerseRange]) -> [[VerseRange]] {
        var groups: [[VerseRange]] = []
        for range in ranges {
            if range.continues, !groups.isEmpty {
                groups[groups.count - 1].append(range)
            } else {
                groups.append([range])
            }
        }
        return groups
    }

    // MARK: - Segments

    private static func slice(
        _ row: StoredVerse,
        fromPart: String?,
        toPart: String?
    ) -> (verse: VerseText, fullVerseShown: Bool) {
        let segments = decodeSegments(row.segmentsJSON)
        let needsParts = fromPart != nil || toPart != nil
        let hasParts = segments.contains { $0.part != nil }

        if needsParts, !hasParts {
            return (
                VerseText(chapter: row.chapter, verse: row.verse, spans: [ReadingSpan(text: row.text, style: nil)]),
                true
            )
        }

        let filtered: [BibleSegment]
        if hasParts, needsParts {
            filtered = segments.filter { segment in
                guard let part = segment.part else { return false }
                if let fromPart, part < fromPart { return false }
                if let toPart, part > toPart { return false }
                return true
            }
        } else {
            filtered = segments
        }

        if filtered.isEmpty {
            return (
                VerseText(chapter: row.chapter, verse: row.verse, spans: [ReadingSpan(text: row.text, style: nil)]),
                needsParts && hasParts == false
            )
        }
        let spans = filtered.map { ReadingSpan(text: $0.t, style: $0.style) }
        return (VerseText(chapter: row.chapter, verse: row.verse, spans: spans), false)
    }

    private static func decodeSegments(_ json: String?) -> [BibleSegment] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([BibleSegment].self, from: data)) ?? []
    }

    // MARK: - Acclamation

    private static func acclamationPhrases(
        for item: LectionaryItem,
        day: LiturgicalDay,
        formulas: LectionaryFormulas
    ) -> [String] {
        guard item.slot == "acclamation" else { return [] }
        if let refrain = item.refrain, !refrain.isEmpty {
            return [refrain]
        }
        if let season = formulas.acclamation[day.season.formulaKey], !season.isEmpty {
            return season
        }
        return formulas.acclamation["default"] ?? []
    }

    // MARK: - Sets

    private static func grouped(_ items: [LectionaryItem]) -> [(id: String?, items: [LectionaryItem])] {
        var groups: [(id: String?, items: [LectionaryItem])] = []
        for item in items {
            if let last = groups.last, last.id == item.set {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append((id: item.set, items: [item]))
            }
        }
        return groups
    }
}

// MARK: - Verse overrides

private nonisolated struct OverrideIndex: Sendable {
    private var byKey: [String: String]

    init(_ overrides: [VerseOverride]) {
        var map: [String: String] = [:]
        map.reserveCapacity(overrides.count)
        for override in overrides {
            map["\(override.book)|\(override.chapter)|\(override.verse)"] = override.text
        }
        byKey = map
    }

    func text(book: String, chapter: Int, verse: Int) -> String? {
        byKey["\(book)|\(chapter)|\(verse)"]
    }
}

// MARK: - Parsing

private nonisolated struct Point: Equatable {
    var chapter: Int
    var verse: Int
    var part: String?

    static func parse(_ text: String) -> Point? {
        let pattern = #/^([1-9]\d*):([1-9]\d*)([a-z])?$/#
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        guard let chapter = Int(match.1), let verse = Int(match.2) else { return nil }
        let part = match.3.map(String.init)
        return Point(chapter: chapter, verse: verse, part: part)
    }
}

private nonisolated struct VerseKey: Equatable {
    var chapter: Int
    var verse: Int
}

extension BibleReader: VerseSource {
    func verses(
        version: String,
        book: String,
        fromChapter: Int,
        fromVerse: Int,
        toChapter: Int,
        toVerse: Int
    ) async -> [StoredVerse] {
        (try? verses(
            versionID: version,
            bookID: book,
            fromChapter: fromChapter,
            fromVerse: fromVerse,
            toChapter: toChapter,
            toVerse: toVerse
        )) ?? []
    }
}
