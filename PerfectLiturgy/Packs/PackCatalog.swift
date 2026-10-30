import Foundation

/// Pack ids come from the server and become URL paths and file names.
/// Letters, digits, `-` and `_` only, so an id can never name another folder.
nonisolated enum PackID {
    static func isValid(_ id: String) -> Bool {
        guard !id.isEmpty, id.utf8.count <= 64 else { return false }
        return id.utf8.allSatisfy { byte in
            (byte >= 97 && byte <= 122) || (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
                || byte == 45 || byte == 95
        }
    }
}

nonisolated struct PackRecord: Codable, Equatable, Sendable, Identifiable {
    var packId: String
    var type: String
    var language: String?
    /// Full language name from the catalog, such as `Efik`. The code stays on `language`.
    var languageName: String?
    var displayName: String
    var revision: String
    var size: Int?
    var requiresSignIn: Bool
    var mode: String
    var metadata: PackMetadata?

    var id: String { packId }

    /// The language name to show. The catalog's `language_name` when it sends one, else the pack's display name.
    /// Nothing here knows a language: the name is whatever the pack list says.
    var languageLabel: String {
        for value in [languageName, displayName] {
            let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { return text }
        }
        return language ?? packId
    }

    init(
        packId: String,
        type: String,
        language: String?,
        languageName: String? = nil,
        displayName: String,
        revision: String = "",
        size: Int? = nil,
        requiresSignIn: Bool = true,
        mode: String,
        metadata: PackMetadata? = nil
    ) {
        self.packId = packId
        self.type = type
        self.language = language
        self.languageName = languageName
        self.displayName = displayName
        self.revision = revision
        self.size = size
        self.requiresSignIn = requiresSignIn
        self.mode = mode
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case packId
        case type
        case language
        case languageName
        case displayName
        case revision
        case size
        case requiresSignIn
        case mode
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packId = try container.decode(String.self, forKey: .packId)
        type = try container.decode(String.self, forKey: .type)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        languageName = try container.decodeIfPresent(String.self, forKey: .languageName)
        displayName = try container.decode(String.self, forKey: .displayName)
        revision = try container.decodeIfPresent(String.self, forKey: .revision) ?? ""
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        requiresSignIn = try container.decodeIfPresent(Bool.self, forKey: .requiresSignIn) ?? true
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "download"
        metadata = try container.decodeIfPresent(PackMetadata.self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(packId, forKey: .packId)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(languageName, forKey: .languageName)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(revision, forKey: .revision)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encode(requiresSignIn, forKey: .requiresSignIn)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// Type-specific catalog extras. Readings use `versification` and `coverageThrough`. Calendars use `region`.
nonisolated struct PackMetadata: Codable, Equatable, Sendable {
    var versification: String?
    var coverageThrough: String?
    var region: String?
}

struct PackListEnvelope: Decodable, Sendable {
    var data: [PackRecord]
    var page: Int
    var pageSize: Int
    var total: Int
}

struct PackSection: Identifiable, Equatable, Sendable {
    var title: String
    var packs: [PackRecord]
    var id: String { title }
}

enum PackSections {
    static let typeOrder = ["readings", "calendar", "hymns", "order", "rosary", "litanies", "stations", "prayers"]

    static func title(for type: String) -> String {
        switch type {
        case "readings": "Daily Readings"
        case "calendar": "Calendars"
        case "hymns": "Hymns"
        case "order": "Order of Mass"
        case "rosary": "Rosary"
        case "litanies": "Litanies"
        case "stations": "Stations of the Cross"
        case "prayers": "Prayers"
        default: type
        }
    }

    static func group(_ packs: [PackRecord]) -> [PackSection] {
        let known = Set(typeOrder)
        var buckets: [String: [PackRecord]] = [:]
        var extras: [String] = []
        for pack in packs {
            buckets[pack.type, default: []].append(pack)
            if !known.contains(pack.type), !extras.contains(pack.type) {
                extras.append(pack.type)
            }
        }
        return (typeOrder + extras).compactMap { type in
            guard let rows = buckets[type], !rows.isEmpty else { return nil }
            let sorted = rows.sorted { lhs, rhs in
                let left = rank(lhs.language)
                let right = rank(rhs.language)
                if left != right { return left < right }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return PackSection(title: title(for: type), packs: sorted)
        }
    }

    /// The default language leads. Every other row sorts by its display name.
    private static func rank(_ language: String?) -> Int {
        language == PackLanguages.defaultCode ? 0 : 1
    }
}

enum PackSize {
    static func text(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        let kilobytes = max(1, Int((Double(bytes) / 1000).rounded()))
        return "\(kilobytes) KB"
    }
}

/// Catalog `coverage_through` dates for Downloads copy.
enum PackCoverage {
    static func text(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return raw
        }
        let date = CivilDate(year: year, month: month, day: day)
        let formatter = DateFormatter()
        formatter.calendar = CivilDate.calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date.date)
    }
}

enum PackLocale {
    /// A calendar whose `language` or pack id suffix is this device's region code.
    static func recommendedCalendar(in packs: [PackRecord], region: String?) -> PackRecord? {
        guard let code = region?.lowercased(), !code.isEmpty else { return nil }
        return packs.first { pack in
            guard pack.type == "calendar" else { return false }
            if pack.language?.lowercased() == code { return true }
            return suffix(of: pack.packId) == code
        }
    }

    private static func suffix(of packId: String) -> String {
        guard let tail = packId.split(separator: "-", maxSplits: 1).last else { return "" }
        return String(tail).lowercased()
    }
}

/// The packs that ship inside the app. They name their own language, like any catalog row,
/// and they stand in until the first catalog fetch. Delete a row here and the app forgets that pack.
nonisolated enum PackSeed {
    static let rows: [PackRecord] = [
        row("hymns-en", type: "hymns", language: "en", languageName: "English", name: "English Hymns", mode: "live"),
        row("hymns-la", type: "hymns", language: "la", languageName: "Latin", name: "Latin Hymns", mode: "live"),
        row("order-en", type: "order", language: "en", languageName: "English", name: "Order of Mass · English", mode: "download"),
        row("order-la", type: "order", language: "la", languageName: "Latin", name: "Order of Mass · Latin", mode: "download"),
        row("rosary-en", type: "rosary", language: "en", languageName: "English", name: "Rosary · English", mode: "download"),
        row("rosary-la", type: "rosary", language: "la", languageName: "Latin", name: "Rosary · Latin", mode: "download"),
        row("litanies-en", type: "litanies", language: "en", languageName: "English", name: "Litanies · English", mode: "download"),
        row("litanies-la", type: "litanies", language: "la", languageName: "Latin", name: "Litanies · Latin", mode: "download"),
        row("stations-en", type: "stations", language: "en", languageName: "English", name: "Stations of the Cross · English", mode: "download"),
        row("stations-la", type: "stations", language: "la", languageName: "Latin", name: "Stations of the Cross · Latin", mode: "download"),
        row("prayers-en", type: "prayers", language: "en", languageName: "English", name: "Prayers · English", mode: "download"),
        row("prayers-la", type: "prayers", language: "la", languageName: "Latin", name: "Prayers · Latin", mode: "download"),
    ]

    private static func row(
        _ id: String,
        type: String,
        language: String,
        languageName: String,
        name: String,
        mode: String
    ) -> PackRecord {
        PackRecord(
            packId: id,
            type: type,
            language: language,
            languageName: languageName,
            displayName: name,
            requiresSignIn: true,
            mode: mode
        )
    }
}

extension Notification.Name {
    /// Posted after the saved pack list is written. Screens that show pack names read it again.
    nonisolated static let packCatalogDidChange = Notification.Name("com.perfectliturgy.packCatalogDidChange")
}

/// The last catalog fetched from the API. `updatedAt` is when that fetch succeeded.
nonisolated struct StoredCatalog: Codable, Equatable, Sendable {
    var packs: [PackRecord]
    var updatedAt: Date?
}

nonisolated enum PackFiles {
    static let catalogName = "catalog.json"
    static let revisionsKey = "packRevisions"

    static func file(for packId: String, root: URL) -> URL {
        // An id that is not safe never reaches here from the app. This keeps a stray one inside the folder.
        let name = PackID.isValid(packId) ? packId : "invalid-pack"
        return root.appending(path: "\(name).json")
    }

    static func catalogFile(root: URL) -> URL {
        root.appending(path: catalogName)
    }

    /// The saved catalog when one exists. Seeds stand in until the first successful fetch.
    static func rowsForDisplay(root: URL) -> [PackRecord] {
        if let stored = loadCatalog(root: root), !stored.packs.isEmpty {
            return stored.packs
        }
        return PackSeed.rows
    }

    static func saveCatalog(_ packs: [PackRecord], root: URL, updatedAt: Date = .now) throws {
        try ensureFolder(root)
        let stored = StoredCatalog(packs: packs, updatedAt: updatedAt)
        let data = try encoder.encode(stored)
        try data.write(to: catalogFile(root: root), options: .atomic)
        NotificationCenter.default.post(name: .packCatalogDidChange, object: nil)
    }

    /// The saved pack list, plus any seeded row it leaves out. The language control reads this,
    /// so a language that ships with the app keeps its name when the server omits its row.
    static func rowsWithSeeds(root: URL) -> [PackRecord] {
        let saved = rowsForDisplay(root: root)
        let known = Set(saved.map(\.packId))
        return saved + PackSeed.rows.filter { !known.contains($0.packId) }
    }

    static func loadCatalog(root: URL) -> StoredCatalog? {
        let url = catalogFile(root: root)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if var stored = try? decoder.decode(StoredCatalog.self, from: data) {
            stored.packs = stored.packs.filter { PackID.isValid($0.packId) }
            if !stored.packs.isEmpty { return stored }
        }
        if let packs = try? decoder.decode([PackRecord].self, from: data) {
            let safe = packs.filter { PackID.isValid($0.packId) }
            if !safe.isEmpty { return StoredCatalog(packs: safe, updatedAt: nil) }
        }
        return nil
    }

    static func revision(for packId: String, defaults: UserDefaults) -> String? {
        let stored = defaults.dictionary(forKey: revisionsKey) as? [String: String]
        return stored?[packId]
    }

    static func storeRevision(_ revision: String, for packId: String, defaults: UserDefaults) {
        var stored = defaults.dictionary(forKey: revisionsKey) as? [String: String] ?? [:]
        stored[packId] = revision
        defaults.set(stored, forKey: revisionsKey)
    }

    static func clearRevision(for packId: String, defaults: UserDefaults) {
        var stored = defaults.dictionary(forKey: revisionsKey) as? [String: String] ?? [:]
        stored.removeValue(forKey: packId)
        defaults.set(stored, forKey: revisionsKey)
    }

    static func clearAllReadingsRevisions(defaults: UserDefaults) {
        var stored = defaults.dictionary(forKey: revisionsKey) as? [String: String] ?? [:]
        for key in stored.keys where key.hasPrefix("readings-") {
            stored.removeValue(forKey: key)
        }
        defaults.set(stored, forKey: revisionsKey)
    }

    /// Downloaded packs can be downloaded again, and some are gated. They stay out of device backups.
    static func ensureFolder(_ root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var folder = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
