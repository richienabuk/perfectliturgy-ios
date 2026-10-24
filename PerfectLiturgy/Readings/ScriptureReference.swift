import Foundation

/// A book, chapter, and verse the local Bible can look up.
nonisolated struct VersePoint: Hashable, Sendable {
    var book: String
    var chapter: Int
    var verse: Int
}

/// `display_window` around the day a readings pack was applied.
nonisolated enum VerseWindow {
    static let day = "day"
    static let week = "week"
    static let month = "month"

    static func contains(_ date: CivilDate, window: String, anchor: CivilDate) -> Bool {
        switch window {
        case week:
            let start = anchor.sundayOnOrBefore
            return date >= start && date <= start.adding(days: 6)
        case month:
            return date.year == anchor.year && date.month == anchor.month
        default:
            return date == anchor
        }
    }
}

/// Turns a lectionary reference into verse keys. Returns nil when the citation cannot be listed verse by verse.
nonisolated enum ScriptureReference {
    static func code(for name: String) -> String? {
        aliases[normalize(name)]
    }

    static func verses(in reference: String) -> [VersePoint]? {
        var text = normalize(reference)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("cf ") {
            text = String(text.dropFirst(3))
        }
        guard !text.contains(" or "), !text.contains("["), !text.contains("]") else { return nil }

        var book: String?
        var singleChapter = false
        var points: [VersePoint] = []
        for segment in text.split(separator: ";") {
            let piece = segment.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { return nil }
            let parsed = matchBook(in: piece)
            let code = parsed?.code ?? book
            let single = parsed?.singleChapter ?? singleChapter
            let spec = parsed?.rest ?? piece
            guard let code, !spec.isEmpty else { return nil }
            guard let listed = expand(book: code, spec: spec, singleChapter: single) else { return nil }
            book = code
            singleChapter = single
            points.append(contentsOf: listed)
        }
        return points.isEmpty ? nil : points
    }

    private static func matchBook(in segment: String) -> (code: String, rest: String, singleChapter: Bool)? {
        for name in namesByLength {
            guard segment.hasPrefix(name) else { continue }
            let rest = segment.dropFirst(name.count)
            guard rest.isEmpty || rest.first == " " else { continue }
            guard let code = aliases[name] else { continue }
            return (code, rest.trimmingCharacters(in: .whitespaces), singleChapterBooks.contains(code))
        }
        return nil
    }

    private static func expand(book: String, spec: String, singleChapter: Bool) -> [VersePoint]? {
        var chapter: Int?
        var points: [VersePoint] = []
        for raw in spec.split(separator: ",") {
            let piece = raw.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { return nil }
            if piece.contains(":") {
                if spansChapters(piece) { return nil }
                let parts = piece.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, let next = Int(parts[0]), next > 0 else { return nil }
                guard let verses = verseSpan(String(parts[1])) else { return nil }
                chapter = next
                points.append(contentsOf: verses.map { VersePoint(book: book, chapter: next, verse: $0) })
            } else if let chapter {
                guard let verses = verseSpan(piece) else { return nil }
                points.append(contentsOf: verses.map { VersePoint(book: book, chapter: chapter, verse: $0) })
            } else if singleChapter {
                guard let verses = verseSpan(piece) else { return nil }
                chapter = 1
                points.append(contentsOf: verses.map { VersePoint(book: book, chapter: 1, verse: $0) })
            } else {
                return nil
            }
        }
        return points.isEmpty ? nil : points
    }

    /// `3:12-4:2` and `32-4:4` span two chapters. Those stay a reference until every verse can be named.
    private static func spansChapters(_ piece: String) -> Bool {
        let parts = piece.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return false }
        return parts[0].contains("-") || parts[1].contains(":")
    }

    private static func verseSpan(_ raw: String) -> [Int]? {
        guard !raw.contains(":") else { return nil }
        let cleaned = raw.filter { $0.isNumber || $0 == "-" }
        let parts = cleaned.split(separator: "-").compactMap { Int($0) }
        if parts.count == 1, let verse = parts.first, verse > 0 {
            return [verse]
        }
        guard parts.count == 2, let start = parts.first, let end = parts.last, start > 0, end >= start, end - start < 180 else {
            return nil
        }
        return Array(start...end)
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let singleChapterBooks: Set<String> = ["obadiah", "philemon", "2 john", "3 john", "jude"]

    private static let aliases: [String: String] = {
        var map: [String: String] = [:]
        let rows: [(String, [String])] = [
            ("genesis", ["genesis", "gen"]),
            ("exodus", ["exodus", "exod", "ex"]),
            ("leviticus", ["leviticus", "lev"]),
            ("numbers", ["numbers", "num"]),
            ("deuteronomy", ["deuteronomy", "deut", "dt"]),
            ("joshua", ["joshua", "josh"]),
            ("judges", ["judges", "judg", "jdg"]),
            ("ruth", ["ruth"]),
            ("1 samuel", ["1 samuel", "1 sam", "1sam"]),
            ("2 samuel", ["2 samuel", "2 sam", "2sam"]),
            ("1 kings", ["1 kings", "1 kgs", "1kgs"]),
            ("2 kings", ["2 kings", "2 kgs", "2kgs"]),
            ("1 chronicles", ["1 chronicles", "1 chr", "1chr"]),
            ("2 chronicles", ["2 chronicles", "2 chr", "2chr"]),
            ("ezra", ["ezra", "ezr"]),
            ("nehemiah", ["nehemiah", "neh"]),
            ("tobit", ["tobit", "tob"]),
            ("judith", ["judith", "jdt"]),
            ("esther", ["esther", "esth", "est"]),
            ("1 maccabees", ["1 maccabees", "1 macc", "1macc"]),
            ("2 maccabees", ["2 maccabees", "2 macc", "2macc"]),
            ("job", ["job"]),
            ("psalm", ["psalm", "psalms", "ps"]),
            ("proverbs", ["proverbs", "prov"]),
            ("ecclesiastes", ["ecclesiastes", "ecclesiastes/qoh", "eccl", "qoh"]),
            ("song of songs", ["song of songs", "song", "sg"]),
            ("wisdom", ["wisdom", "wis"]),
            ("sirach", ["sirach", "sir"]),
            ("isaiah", ["isaiah", "isa"]),
            ("jeremiah", ["jeremiah", "jer"]),
            ("lamentations", ["lamentations", "lam"]),
            ("baruch", ["baruch", "bar"]),
            ("ezekiel", ["ezekiel", "ezek"]),
            ("daniel", ["daniel", "dan"]),
            ("hosea", ["hosea", "hos"]),
            ("joel", ["joel"]),
            ("amos", ["amos", "am"]),
            ("obadiah", ["obadiah", "obad"]),
            ("jonah", ["jonah", "jon"]),
            ("micah", ["micah", "mic"]),
            ("nahum", ["nahum", "nah"]),
            ("habakkuk", ["habakkuk", "hab"]),
            ("zephaniah", ["zephaniah", "zeph"]),
            ("haggai", ["haggai", "hag"]),
            ("zechariah", ["zechariah", "zech"]),
            ("malachi", ["malachi", "mal"]),
            ("matthew", ["matthew", "matt", "mt"]),
            ("mark", ["mark", "mk"]),
            ("luke", ["luke", "lk"]),
            ("john", ["john", "jn"]),
            ("acts", ["acts"]),
            ("romans", ["romans", "rom"]),
            ("1 corinthians", ["1 corinthians", "1 cor", "1cor"]),
            ("2 corinthians", ["2 corinthians", "2 cor", "2cor"]),
            ("galatians", ["galatians", "gal"]),
            ("ephesians", ["ephesians", "eph"]),
            ("philippians", ["philippians", "phil"]),
            ("colossians", ["colossians", "col"]),
            ("1 thessalonians", ["1 thessalonians", "1 thess", "1thess"]),
            ("2 thessalonians", ["2 thessalonians", "2 thess", "2thess"]),
            ("1 timothy", ["1 timothy", "1 tim", "1tim"]),
            ("2 timothy", ["2 timothy", "2 tim", "2tim"]),
            ("titus", ["titus", "tit"]),
            ("philemon", ["philemon", "phlm", "philem"]),
            ("hebrews", ["hebrews", "heb"]),
            ("james", ["james", "jas"]),
            ("1 peter", ["1 peter", "1 pet", "1pet"]),
            ("2 peter", ["2 peter", "2 pet", "2pet"]),
            ("1 john", ["1 john", "1 jn", "1jn"]),
            ("2 john", ["2 john", "2 jn", "2jn"]),
            ("3 john", ["3 john", "3 jn", "3jn"]),
            ("jude", ["jude"]),
            ("revelation", ["revelation", "rev"]),
        ]
        for (canonical, names) in rows {
            for name in names {
                map[name] = canonical
            }
        }
        return map
    }()

    private static let namesByLength: [String] = aliases.keys.sorted { $0.count > $1.count }
}
