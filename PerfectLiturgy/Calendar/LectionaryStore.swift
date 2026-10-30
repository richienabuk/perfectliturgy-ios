import Foundation

/// Decodes a lectionary file once and caches it by `(calendarID, revision)`.
actor LectionaryStore {
    static let shared = LectionaryStore()

    private var cache: [String: Lectionary] = [:]

    /// The bundled Latin Rite seed. Citations and slot headings only.
    func seed(bundle: Bundle = .main) -> Lectionary {
        let id = "latin-rite"
        if let cached = cache.values.first(where: { $0.id == id }) {
            return cached
        }
        guard
            let url = bundle.url(forResource: "lectionary-latin-rite", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let lectionary = try? Self.decode(data)
        else {
            return .empty
        }
        cache[cacheKey(id: lectionary.id, revision: lectionary.revision)] = lectionary
        return lectionary
    }

    func lectionary(id: String, revision: String, data: Data) throws -> Lectionary {
        let key = cacheKey(id: id, revision: revision)
        if let cached = cache[key] { return cached }
        let decoded = try Self.decode(data)
        cache[key] = decoded
        return decoded
    }

    func invalidate(id: String) {
        cache = cache.filter { $0.value.id != id }
    }

    private func cacheKey(id: String, revision: String) -> String {
        "\(id)|\(revision)"
    }

    /// Decodes a seed (top-level tables) or a calendar pack (`data` wrapper).
    nonisolated static func decode(_ data: Data) throws -> Lectionary {
        if let pack = try? decodePack(data) {
            return pack
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let seed = try decoder.decode(SeedEnvelope.self, from: data)
        return seed.lectionary
    }

    /// Calendar pack envelope only (`pack_id` + `data` tables). Rejects the seed and days-only shapes.
    nonisolated static func decodePack(_ data: Data) throws -> Lectionary {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let pack = try decoder.decode(PackEnvelope.self, from: data)
        return pack.lectionary
    }
}

// MARK: - Decoding

private nonisolated struct SeedEnvelope: Decodable {
    var calendarId: String
    var revision: String
    var displayName: String
    var language: String
    var formulas: FormulasDTO?
    var sunday: [String: [ItemDTO]]
    var feria: [String: [ItemDTO]]
    var proper: [String: [ItemDTO]]
    var days: [DayDTO]?

    var lectionary: Lectionary {
        Lectionary(
            id: calendarId,
            language: language,
            displayName: displayName,
            revision: revision,
            formulas: (formulas ?? .empty).value,
            sunday: sunday.mapValues { $0.map(\.value) },
            feria: feria.mapValues { $0.map(\.value) },
            proper: proper.mapValues { $0.map(\.value) },
            days: (days ?? []).compactMap(\.celebration)
        )
    }
}

private nonisolated struct PackEnvelope: Decodable {
    var packId: String
    var language: String
    var revision: String
    var displayName: String?
    var metadata: RegionDTO?
    var data: PackDataDTO

    var lectionary: Lectionary {
        Lectionary(
            id: packId,
            language: language,
            displayName: displayName ?? packId,
            revision: revision,
            formulas: (data.formulas ?? .empty).value,
            sunday: data.sunday.mapValues { $0.map(\.value) },
            feria: data.feria.mapValues { $0.map(\.value) },
            proper: data.proper.mapValues { $0.map(\.value) },
            days: data.days.compactMap(\.celebration)
        )
    }
}

private nonisolated struct PackDataDTO: Decodable {
    var days: [DayDTO]
    var formulas: FormulasDTO?
    var sunday: [String: [ItemDTO]]
    var feria: [String: [ItemDTO]]
    var proper: [String: [ItemDTO]]
}

private nonisolated struct RegionDTO: Decodable {
    var region: String?
}

private nonisolated struct FormulasDTO: Decodable {
    var sets: [String: String]?
    var slots: [String: SlotDTO]?
    var bookTitles: [String: String]?
    var acclamation: [String: [String]]?

    static let empty = FormulasDTO(sets: nil, slots: nil, bookTitles: nil, acclamation: nil)

    var value: LectionaryFormulas {
        LectionaryFormulas(
            sets: sets ?? [:],
            slots: (slots ?? [:]).mapValues { LectionarySlotFormula(label: $0.label, closing: $0.closing) },
            bookTitles: bookTitles ?? [:],
            acclamation: acclamation ?? [:]
        )
    }
}

private nonisolated struct SlotDTO: Decodable {
    var label: String?
    var closing: String?
}

private nonisolated struct DayDTO: Decodable {
    var id: String
    var title: String
    var color: String
    var month: Int
    var day: Int
    var year: Int?

    var celebration: CountryCelebration? {
        guard let color = LiturgicalColor(rawValue: color.lowercased()) else { return nil }
        return CountryCelebration(id: id, title: title, color: color, month: month, day: day, year: year)
    }
}

private nonisolated struct ItemDTO: Decodable {
    var slot: String
    var reference: String?
    var ranges: [RangeDTO]?
    var set: String?
    var label: String?
    var incipit: String?
    var theme: String?
    var refrain: String?
    var refrainRef: String?
    var closing: String?
    var cf: Bool?
    var alternatives: [AlternativeDTO]?
    var text: BodyDTO?
    var verseOverrides: [VerseOverrideDTO]?

    var value: LectionaryItem {
        LectionaryItem(
            slot: slot,
            reference: reference,
            ranges: (ranges ?? []).map(\.value),
            set: set,
            label: label,
            incipit: incipit,
            theme: theme,
            refrain: refrain,
            refrainRef: refrainRef,
            closing: closing,
            cf: cf ?? false,
            alternatives: (alternatives ?? []).map(\.value),
            text: text?.value,
            verseOverrides: (verseOverrides ?? []).map(\.value)
        )
    }
}

private nonisolated struct AlternativeDTO: Decodable {
    var label: String?
    var reference: String?
    var ranges: [RangeDTO]?
    var incipit: String?
    var theme: String?
    var refrain: String?
    var refrainRef: String?
    var text: BodyDTO?
    var verseOverrides: [VerseOverrideDTO]?

    var value: LectionaryAlternative {
        LectionaryAlternative(
            label: label,
            reference: reference,
            ranges: (ranges ?? []).map(\.value),
            incipit: incipit,
            theme: theme,
            refrain: refrain,
            refrainRef: refrainRef,
            text: text?.value,
            verseOverrides: (verseOverrides ?? []).map(\.value)
        )
    }
}

private nonisolated struct VerseOverrideDTO: Decodable {
    var book: String
    var chapter: Int
    var verse: Int
    var text: String

    var value: VerseOverride {
        VerseOverride(book: book, chapter: chapter, verse: verse, text: text)
    }
}

private nonisolated struct RangeDTO: Decodable {
    var book: String
    var from: String
    var to: String
    var continues: Bool?

    var value: VerseRange {
        VerseRange(book: book, from: from, to: to, continues: continues ?? false)
    }
}

private nonisolated struct BodyDTO: Decodable {
    var paragraphs: [String]?
    var stanzas: [StanzaDTO]?

    var value: LectionaryBody? {
        if let paragraphs, !paragraphs.isEmpty {
            return .paragraphs(paragraphs)
        }
        if let stanzas, !stanzas.isEmpty {
            return .stanzas(stanzas.map(\.lines))
        }
        return nil
    }
}

private nonisolated struct StanzaDTO: Decodable {
    var lines: [String]
}
