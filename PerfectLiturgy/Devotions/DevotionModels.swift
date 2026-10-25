import Foundation

nonisolated enum DevotionKind: String, CaseIterable, Sendable {
    case order
    case rosary
    case stations
    case litanies
    case prayers

    var screenTitle: String {
        switch self {
        case .order: "Order of Mass"
        case .rosary: "Holy Rosary"
        case .stations: "Stations of the Cross"
        case .litanies: "Litanies"
        case .prayers: "Special Prayers"
        }
    }

    var support: String {
        switch self {
        case .order: "The fixed texts of the Mass."
        case .rosary: "A step-by-step guide, from the crucifix to the closing prayer."
        case .stations: "Fourteen stations with reflections."
        case .litanies: "Call and response."
        case .prayers: "Prayers for daily life."
        }
    }

    var languageTitle: String {
        switch self {
        case .order: "Order of Mass language"
        case .rosary: "Rosary language"
        case .stations: "Stations language"
        case .litanies: "Litanies language"
        case .prayers: "Prayers language"
        }
    }
}

/// The language the reader is using, and whether Downloads is the way forward.
/// `languages` are the installed ones for this pack type, named by the pack list.
nonisolated struct DevotionLanguageChoice: Equatable, Sendable {
    var requested: String?
    /// The name the pack list gives the requested language, when it lists one.
    var requestedName: String?
    var languages: [PackLanguage]

    init(requested: String?, requestedName: String? = nil, languages: [PackLanguage]) {
        self.requested = requested
        self.requestedName = requestedName
        self.languages = languages
    }

    /// Build the choice for one devotion from the saved pack list.
    init(_ kind: DevotionKind, requested: String?, installed: [String], catalog: [PackRecord]) {
        let type = kind.rawValue
        self.init(
            requested: requested,
            requestedName: requested.flatMap { code in
                PackLanguages.record(code: code, type: type, in: catalog) == nil
                    ? nil
                    : PackLanguages.language(code: code, type: type, in: catalog).name
            },
            languages: PackLanguages.list(codes: installed, type: type, in: catalog)
        )
    }

    private var activeLanguage: PackLanguage? {
        PackLanguages.active(requested: requested, in: languages)
    }

    var active: String? { activeLanguage?.code }

    /// A chosen language is not on the device, or nothing is installed.
    var offersDownloads: Bool {
        if let requested, !languages.contains(where: { $0.code == requested }) {
            return true
        }
        return languages.isEmpty
    }

    var message: String {
        guard let requestedName else {
            return "This language is not on this device."
        }
        return "\(requestedName) is not on this device."
    }

    var buttonTitle: String {
        activeLanguage?.name ?? requestedName ?? "Language"
    }

    /// What to say when the reader cannot show this language.
    var unavailableMessage: String {
        if let activeLanguage, !offersDownloads {
            return "\(activeLanguage.name) is not on this device."
        }
        return message
    }
}

nonisolated struct MassPart: Equatable, Sendable, Identifiable {
    var order: Int
    var title: String
    var summary: String?
    var items: [MassItem]
    var id: Int { order }
}

nonisolated struct MassItem: Equatable, Sendable, Identifiable {
    var order: Int
    var title: String
    var rubric: String?
    var text: String?
    var response: String?
    var id: Int { order }
}

nonisolated struct RosaryPrayers: Equatable, Sendable {
    var sign: String
    var creed: String
    var ourFather: String
    var hailMary: String
    var gloryBe: String
    var fatima: String
    var hailHolyQueen: String
    var closing: String
}

nonisolated struct RosaryMysterySet: Equatable, Sendable, Identifiable {
    var order: Int
    var id: String
    var title: String
    var days: String?
    var titles: [String]
}

nonisolated struct RosaryPack: Equatable, Sendable {
    var prayers: RosaryPrayers
    var mysteries: [RosaryMysterySet]
}

nonisolated struct Station: Equatable, Sendable, Identifiable {
    var order: Int
    var id: String
    var title: String
    var reference: String?
    var meditation: String
    var prayer: String
}

nonisolated struct Litany: Equatable, Sendable, Identifiable {
    var order: Int
    var id: String
    var title: String
    var summary: String?
    var category: String?
    var lines: [LitanyLine]
}

nonisolated struct LitanyLine: Equatable, Sendable, Identifiable {
    var order: Int
    var call: String
    var response: String?
    var id: Int { order }
}

nonisolated struct SpecialPrayer: Equatable, Sendable, Identifiable {
    var order: Int
    var id: String
    var title: String
    var summary: String?
    var category: String?
    var text: String
}

nonisolated enum DevotionBody: Equatable, Sendable {
    case order(language: String, parts: [MassPart])
    case rosary(language: String, pack: RosaryPack)
    case stations(language: String, stations: [Station])
    case litanies(language: String, litanies: [Litany])
    case prayers(language: String, prayers: [SpecialPrayer])

    var language: String {
        switch self {
        case .order(let language, _),
             .rosary(let language, _),
             .stations(let language, _),
             .litanies(let language, _),
             .prayers(let language, _):
            language
        }
    }

    var isEmpty: Bool {
        switch self {
        case .order(_, let parts): parts.isEmpty
        case .rosary(_, let pack): pack.mysteries.isEmpty
        case .stations(_, let stations): stations.isEmpty
        case .litanies(_, let litanies): litanies.isEmpty
        case .prayers(_, let prayers): prayers.isEmpty
        }
    }
}

nonisolated enum DevotionID {
    static func slug(_ title: String) -> String {
        let folded = AccentFold.fold(title)
        var result = ""
        var pendingDash = false
        for character in folded {
            if character.isLetter || character.isNumber {
                if pendingDash, !result.isEmpty {
                    result.append("-")
                }
                pendingDash = false
                result.append(character)
            } else {
                pendingDash = true
            }
        }
        return result.isEmpty ? "item" : result
    }
}

/// Roles the devotion readers send through the heading and body sliders.
nonisolated enum DevotionText {
    static let part = ReadingRole.partTitle
    static let item = ReadingRole.itemTitle
    static let prayer = ReadingRole.prayer
    static let response = ReadingRole.response
}
