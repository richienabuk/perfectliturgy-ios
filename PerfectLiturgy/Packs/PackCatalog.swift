import Foundation

struct PackRecord: Codable, Equatable, Sendable, Identifiable {
    var packId: String
    var type: String
    var language: String?
    var displayName: String
    var revision: String
    var size: Int?
    var requiresSignIn: Bool
    var mode: String
    var metadata: PackMetadata?

    var id: String { packId }

    init(
        packId: String,
        type: String,
        language: String?,
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
        try container.encode(displayName, forKey: .displayName)
        try container.encode(revision, forKey: .revision)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encode(requiresSignIn, forKey: .requiresSignIn)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// Type-specific catalog extras. Readings use `displayWindow` (`day`, `week`, or `month`).
struct PackMetadata: Codable, Equatable, Sendable {
    var displayWindow: String?
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

    private static func rank(_ language: String?) -> Int {
        switch language {
        case "en": 0
        case "la": 1
        default: 2
        }
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

enum PackSeed {
    static let rows: [PackRecord] = [
        row("hymns-en", type: "hymns", language: "en", name: "English Hymns", mode: "live"),
        row("hymns-la", type: "hymns", language: "la", name: "Latin Hymns", mode: "live"),
        row("order-en", type: "order", language: "en", name: "Order of Mass · English", mode: "download"),
        row("order-la", type: "order", language: "la", name: "Order of Mass · Latin", mode: "download"),
        row("rosary-en", type: "rosary", language: "en", name: "Rosary · English", mode: "download"),
        row("rosary-la", type: "rosary", language: "la", name: "Rosary · Latin", mode: "download"),
        row("litanies-en", type: "litanies", language: "en", name: "Litanies · English", mode: "download"),
        row("litanies-la", type: "litanies", language: "la", name: "Litanies · Latin", mode: "download"),
        row("stations-en", type: "stations", language: "en", name: "Stations of the Cross · English", mode: "download"),
        row("stations-la", type: "stations", language: "la", name: "Stations of the Cross · Latin", mode: "download"),
        row("prayers-en", type: "prayers", language: "en", name: "Prayers · English", mode: "download"),
        row("prayers-la", type: "prayers", language: "la", name: "Prayers · Latin", mode: "download"),
    ]

    private static func row(
        _ id: String,
        type: String,
        language: String,
        name: String,
        mode: String
    ) -> PackRecord {
        PackRecord(
            packId: id,
            type: type,
            language: language,
            displayName: name,
            requiresSignIn: true,
            mode: mode
        )
    }
}

/// The last catalog fetched from the API. `updatedAt` is when that fetch succeeded.
struct StoredCatalog: Codable, Equatable, Sendable {
    var packs: [PackRecord]
    var updatedAt: Date?
}

enum PackFiles {
    static let catalogName = "catalog.json"
    static let revisionsKey = "packRevisions"

    static func file(for packId: String, root: URL) -> URL {
        root.appending(path: "\(packId).json")
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
    }

    static func loadCatalog(root: URL) -> StoredCatalog? {
        let url = catalogFile(root: root)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let stored = try? decoder.decode(StoredCatalog.self, from: data), !stored.packs.isEmpty {
            return stored
        }
        if let packs = try? decoder.decode([PackRecord].self, from: data), !packs.isEmpty {
            return StoredCatalog(packs: packs, updatedAt: nil)
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

    static func ensureFolder(_ root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
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
