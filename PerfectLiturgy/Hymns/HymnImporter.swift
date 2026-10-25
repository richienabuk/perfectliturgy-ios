import Foundation
import os
import SwiftData

extension Notification.Name {
    /// Posted after hymns are saved or removed. Screens copy rows from the store when they hear it.
    static let hymnStoreDidChange = Notification.Name("com.perfectliturgy.hymnStoreDidChange")
}

struct HymnPayload: Decodable, Equatable {
    var id: String
    var language: String
    var hymnNumber: Int
    var title: String
    var firstLine: String?
    var lyrics: String?
    var sections: [SectionPayload]
    var meter: String?
    var seasons: [String]
    var topics: [String]
    var scriptureReferences: [String]
    var tuneName: String?
    var musicalKey: String?
    var authors: String?
    var massParts: [String]
    var videoURLs: [String]
    var audioURLs: [String]
    var sheetMusicURLs: [String]
    var isPublicDomain: Bool
    var permissionGranted: Bool
    var backgroundNotes: String?
    var deletedAt: String?

    struct SectionPayload: Decodable, Equatable {
        var id: String?
        var type: String
        var label: String?
        var content: String
    }

    private enum CodingKeys: String, CodingKey {
        case id, language, hymnNumber, title, firstLine, lyrics, sections, meter, seasons, topics
        case scriptureReferences, tuneName, key, authors, massParts
        case videoUrl, audioUrl, sheetMusicUrl
        case isPublicDomain, permissionGranted, backgroundNotes, deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        language = try container.decode(String.self, forKey: .language)
        hymnNumber = try container.decode(Int.self, forKey: .hymnNumber)
        title = try container.decode(String.self, forKey: .title)
        firstLine = try container.decodeIfPresent(String.self, forKey: .firstLine)
        lyrics = try container.decodeIfPresent(String.self, forKey: .lyrics)
        sections = try container.decodeIfPresent([SectionPayload].self, forKey: .sections) ?? []
        meter = try container.decodeIfPresent(String.self, forKey: .meter)
        seasons = Self.strings(container, .seasons)
        topics = Self.strings(container, .topics)
        scriptureReferences = Self.strings(container, .scriptureReferences)
        tuneName = try container.decodeIfPresent(String.self, forKey: .tuneName)
        musicalKey = try container.decodeIfPresent(String.self, forKey: .key)
        authors = Self.text(container, .authors)
        massParts = Self.strings(container, .massParts)
        videoURLs = Self.strings(container, .videoUrl)
        audioURLs = Self.strings(container, .audioUrl)
        sheetMusicURLs = Self.strings(container, .sheetMusicUrl)
        isPublicDomain = try container.decodeIfPresent(Bool.self, forKey: .isPublicDomain) ?? false
        permissionGranted = try container.decodeIfPresent(Bool.self, forKey: .permissionGranted) ?? false
        backgroundNotes = try container.decodeIfPresent(String.self, forKey: .backgroundNotes)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
    }

    private static func strings(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String] {
        if let many = try? container.decode([String].self, forKey: key) {
            return many
        }
        if let one = try? container.decode(String.self, forKey: key), !one.isEmpty {
            return [one]
        }
        return []
    }

    private static func text(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let one = try? container.decode(String.self, forKey: key) {
            return one
        }
        let many = strings(container, key)
        let joined = many.joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
}

private struct HymnEnvelope: Decodable {
    var data: [HymnPayload]
}

enum HymnDecoder {
    static func payloads(from data: Data) throws -> [HymnPayload] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let list = try? decoder.decode([HymnPayload].self, from: data) {
            return list
        }
        return try decoder.decode(HymnEnvelope.self, from: data).data
    }
}

enum HymnBundles {
    /// Catalogues only. Fixture files stay in the bundle for tests and are not imported.
    static let resourceNames = [
        "hymns_en_catalogue",
        "hymns_la_catalogue",
    ]

    static func urls(in bundle: Bundle) -> [URL] {
        resourceNames.compactMap { url(for: $0, in: bundle) }
    }

    static func url(for name: String, in bundle: Bundle) -> URL? {
        let folders = [nil, "Fixtures", "Hymns/Fixtures", "Catalogues", "Hymns/Catalogues"]
        for folder in folders {
            if let folder, let url = bundle.url(forResource: name, withExtension: "json", subdirectory: folder) {
                return url
            }
            if folder == nil, let url = bundle.url(forResource: name, withExtension: "json") {
                return url
            }
        }
        return nil
    }
}

enum HymnImporter {
    private static let logger = Logger(subsystem: "com.perfectliturgy", category: "hymns")
    private static let signatureKey = "hymns.importSignature"
    private static let searchKeyVersionKey = "hymns.searchKeyVersion"
    /// Raise this when `HymnSearch.makeKey` changes. Saved hymns then get a new key once.
    /// 2: the key holds section text, so a search no longer folds lyrics for every hymn.
    static let searchKeyVersion = 2

    static func importBundledIfNeeded(
        into context: ModelContext,
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) throws {
        try removeFixtures(in: context)
        try rebuildSearchKeysIfNeeded(in: context, defaults: defaults)
        let urls = HymnBundles.urls(in: bundle)
        let signature = urls.map { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            return "\(url.lastPathComponent):\(size):\(modified)"
        }.joined(separator: "|")
        let existing = try context.fetchCount(FetchDescriptor<HymnRecord>())
        if existing > 0, defaults.string(forKey: signatureKey) == signature {
            return
        }
        let allowed = installedHymnLanguages(defaults: defaults)
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            if let allowed, let language = Self.language(inResourceName: name), !allowed.contains(language) {
                continue
            }
            do {
                try importData(try Data(contentsOf: url), into: context)
            } catch {
                logger.error("Could not import \(url.lastPathComponent, privacy: .public)")
            }
        }
        try save(context)
        if try context.fetchCount(FetchDescriptor<HymnRecord>()) > 0 {
            defaults.set(signature, forKey: signatureKey)
        }
    }

    static func importData(_ data: Data, into context: ModelContext) throws {
        for payload in try HymnDecoder.payloads(from: data) {
            try upsert(payload, into: context)
        }
        try save(context)
    }

    /// Builds the search key again for every saved hymn, from its stored text.
    /// Downloaded languages are not in the app bundle, so this reads the store and not the files.
    static func rebuildSearchKeysIfNeeded(in context: ModelContext, defaults: UserDefaults) throws {
        guard defaults.integer(forKey: searchKeyVersionKey) != searchKeyVersion else { return }
        try rebuildSearchKeys(in: context)
        defaults.set(searchKeyVersion, forKey: searchKeyVersionKey)
    }

    static func rebuildSearchKeys(in context: ModelContext) throws {
        let hymns = try context.fetch(FetchDescriptor<HymnRecord>())
        guard !hymns.isEmpty else { return }
        for hymn in hymns {
            hymn.searchKey = HymnSearch.makeKey(
                title: hymn.title,
                firstLine: hymn.firstLine,
                lyrics: hymn.lyrics,
                sections: hymn.orderedSections.map(\.content)
            )
        }
        try save(context)
    }

    /// Fixture rows use ids such as `test-en-1`. They are for tests, not the hymn list.
    private static func removeFixtures(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<HymnRecord>(predicate: #Predicate { $0.id.starts(with: "test-") })
        let fixtures = try context.fetch(descriptor)
        guard !fixtures.isEmpty else { return }
        for hymn in fixtures {
            context.delete(hymn)
        }
        try save(context)
    }

    /// Deletes every hymn in one language. Bookmarks stay, so Saved can still name them.
    static func removeLanguage(_ language: String, in context: ModelContext) throws {
        let code = language
        let descriptor = FetchDescriptor<HymnRecord>(predicate: #Predicate { $0.language == code })
        for hymn in try context.fetch(descriptor) {
            context.delete(hymn)
        }
        try save(context)
    }

    /// Saves, then tells screens to copy hymn rows again. Reading a deleted row traps.
    private static func save(_ context: ModelContext) throws {
        try context.save()
        NotificationCenter.default.post(name: .hymnStoreDidChange, object: context)
    }

    static func page(id: String, in context: ModelContext) -> HymnPage? {
        guard let hymn = record(id: id, in: context) else { return nil }
        return hymn.page
    }

    static func record(id: String, in context: ModelContext) -> HymnRecord? {
        let hymnID = id
        let descriptor = FetchDescriptor<HymnRecord>(predicate: #Predicate { $0.id == hymnID })
        guard let hymn = try? context.fetch(descriptor).first, !hymn.isDeleted else { return nil }
        return hymn
    }

    static func upsert(_ payload: HymnPayload, into context: ModelContext) throws {
        let byNumber = try fetch(language: payload.language, number: payload.hymnNumber, in: context)
        let byID = try fetch(id: payload.id, in: context)
        let removed = payload.deletedAt?.isEmpty == false
        if removed {
            for match in unique([byNumber, byID]) {
                try removeSaved(id: match.id, in: context)
                context.delete(match)
            }
            return
        }
        if let existing = byNumber ?? byID {
            let previousID = existing.id
            if previousID != payload.id {
                context.delete(existing)
                if let byID, byID.persistentModelID != existing.persistentModelID {
                    context.delete(byID)
                }
                let created = try insert(payload, into: context)
                try retarget(
                    from: previousID,
                    to: created.id,
                    title: created.title,
                    language: created.language,
                    in: context
                )
            } else {
                try fill(existing, with: payload, in: context)
            }
        } else {
            _ = try insert(payload, into: context)
        }
    }

    static func toggleBookmark(_ hymn: HymnRecord, in context: ModelContext) throws {
        if let bookmark = try fetchBookmark(id: hymn.id, in: context) {
            context.delete(bookmark)
        } else {
            context.insert(
                HymnBookmark(
                    hymnId: hymn.id,
                    titleSnapshot: hymn.title,
                    language: hymn.language,
                    createdAt: .now
                )
            )
        }
        try context.save()
    }

    static func removeBookmark(hymnID: String, in context: ModelContext) throws {
        guard let bookmark = try fetchBookmark(id: hymnID, in: context) else { return }
        context.delete(bookmark)
        try context.save()
    }

    static func recordVisit(hymnID: String, in context: ModelContext) throws {
        var visits = try context.fetch(FetchDescriptor<HymnVisit>())
        if let existing = visits.first(where: { $0.hymnId == hymnID }) {
            existing.openedAt = .now
        } else {
            let visit = HymnVisit(hymnId: hymnID, openedAt: .now)
            context.insert(visit)
            visits.append(visit)
        }
        let newest = visits.sorted { $0.openedAt > $1.openedAt }
        for extra in newest.dropFirst(8) {
            context.delete(extra)
        }
        try context.save()
    }

    private static func insert(_ payload: HymnPayload, into context: ModelContext) throws -> HymnRecord {
        let hymn = HymnRecord(
            id: payload.id,
            language: payload.language,
            hymnNumber: payload.hymnNumber,
            title: payload.title,
            firstLine: "",
            lyrics: "",
            searchKey: ""
        )
        context.insert(hymn)
        try fill(hymn, with: payload, in: context)
        return hymn
    }

    private static func fill(_ hymn: HymnRecord, with payload: HymnPayload, in context: ModelContext) throws {
        let sections = payload.sections.enumerated().map { index, section in
            HymnSectionText(
                type: HymnSectionKind(raw: section.type),
                label: section.label ?? "",
                content: section.content
            )
        }
        let lyrics = derivedLyrics(explicit: payload.lyrics, sections: sections)
        let firstLine = derivedFirstLine(explicit: payload.firstLine, sections: sections, lyrics: lyrics)
        hymn.id = payload.id
        hymn.language = payload.language
        hymn.hymnNumber = payload.hymnNumber
        hymn.title = payload.title
        hymn.firstLine = firstLine
        hymn.lyrics = lyrics
        hymn.meter = payload.meter
        hymn.seasons = payload.seasons
        hymn.topics = payload.topics
        hymn.scriptureReferences = payload.scriptureReferences
        hymn.tuneName = payload.tuneName
        hymn.musicalKey = payload.musicalKey
        hymn.authors = payload.authors
        hymn.massParts = payload.massParts
        hymn.videoURLs = payload.videoURLs
        hymn.audioURLs = payload.audioURLs
        hymn.sheetMusicURLs = payload.sheetMusicURLs
        hymn.isPublicDomain = payload.isPublicDomain
        hymn.permissionGranted = payload.permissionGranted
        hymn.backgroundNotes = payload.backgroundNotes
        hymn.searchKey = HymnSearch.makeKey(
            title: payload.title,
            firstLine: firstLine,
            lyrics: lyrics,
            sections: sections.map(\.content)
        )
        for section in hymn.sections {
            context.delete(section)
        }
        hymn.sections = payload.sections.enumerated().map { index, section in
            let record = HymnSectionRecord(
                id: section.id ?? "\(payload.id)#\(index)",
                typeRaw: HymnSectionKind(raw: section.type).rawValue,
                label: section.label ?? "",
                content: section.content,
                position: index
            )
            record.hymn = hymn
            return record
        }
    }

    static func derivedLyrics(explicit: String?, sections: [HymnSectionText]) -> String {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return explicit }
        }
        return sections.map(\.content).joined(separator: "\n")
    }

    static func derivedFirstLine(explicit: String?, sections: [HymnSectionText], lyrics: String) -> String {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return explicit }
        }
        let source = sections.first?.content ?? lyrics
        let line = source.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.trimmingCharacters(in: .whitespaces)
    }

    private static func retarget(
        from oldID: String,
        to newID: String,
        title: String,
        language: String,
        in context: ModelContext
    ) throws {
        if let bookmark = try fetchBookmark(id: oldID, in: context) {
            let createdAt = bookmark.createdAt
            context.delete(bookmark)
            if let clash = try fetchBookmark(id: newID, in: context) {
                context.delete(clash)
            }
            context.insert(
                HymnBookmark(hymnId: newID, titleSnapshot: title, language: language, createdAt: createdAt)
            )
        }
        if let visit = try context.fetch(FetchDescriptor<HymnVisit>()).first(where: { $0.hymnId == oldID }) {
            let openedAt = visit.openedAt
            context.delete(visit)
            context.insert(HymnVisit(hymnId: newID, openedAt: openedAt))
        }
    }

    private static func removeSaved(id: String, in context: ModelContext) throws {
        if let bookmark = try fetchBookmark(id: id, in: context) {
            context.delete(bookmark)
        }
        if let visit = try context.fetch(FetchDescriptor<HymnVisit>()).first(where: { $0.hymnId == id }) {
            context.delete(visit)
        }
    }

    private static func fetch(language: String, number: Int, in context: ModelContext) throws -> HymnRecord? {
        let descriptor = FetchDescriptor<HymnRecord>(
            predicate: #Predicate { $0.language == language && $0.hymnNumber == number }
        )
        return try context.fetch(descriptor).first
    }

    private static func fetch(id: String, in context: ModelContext) throws -> HymnRecord? {
        let descriptor = FetchDescriptor<HymnRecord>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private static func fetchBookmark(id: String, in context: ModelContext) throws -> HymnBookmark? {
        let descriptor = FetchDescriptor<HymnBookmark>(predicate: #Predicate { $0.hymnId == id })
        return try context.fetch(descriptor).first
    }

    private static func unique(_ records: [HymnRecord?]) -> [HymnRecord] {
        var seen: [PersistentIdentifier] = []
        var result: [HymnRecord] = []
        for record in records.compactMap(\.self) {
            if seen.contains(record.persistentModelID) { continue }
            seen.append(record.persistentModelID)
            result.append(record)
        }
        return result
    }

    /// `hymns_en` and `hymns_en_catalogue` both mean English.
    static func language(inResourceName name: String) -> String? {
        var base = name
        let suffix = "_catalogue"
        if base.hasSuffix(suffix) {
            base.removeLast(suffix.count)
        }
        let prefix = "hymns_"
        guard base.hasPrefix(prefix) else { return nil }
        let code = String(base.dropFirst(prefix.count))
        return code.isEmpty ? nil : code
    }

    /// Nil means the installed set was never written, so the bundled languages still apply.
    private static func installedHymnLanguages(defaults: UserDefaults) -> Set<String>? {
        guard defaults.object(forKey: InstalledPacks.storageKey) != nil else { return nil }
        let stored = defaults.stringArray(forKey: InstalledPacks.storageKey) ?? []
        let codes = stored.compactMap { id -> String? in
            guard id.hasPrefix("hymns-") else { return nil }
            let code = String(id.dropFirst("hymns-".count))
            return code.isEmpty ? nil : code
        }
        return Set(codes)
    }
}

enum HymnStore {
    static let shared: ModelContainer = {
        do {
            let container = try make(inMemory: false)
            try HymnImporter.importBundledIfNeeded(into: container.mainContext)
            return container
        } catch {
            fatalError("The hymn store could not be opened.")
        }
    }()

    static func make(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            inMemory ? "hymns-\(UUID().uuidString)" : "hymns",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// A file-backed store, used to prove a bookmark is still there after the app is opened again.
    static func make(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static let schema = Schema([
        HymnRecord.self,
        HymnSectionRecord.self,
        HymnBookmark.self,
        DevotionBookmark.self,
        HymnVisit.self,
        BibleVerseRecord.self,
        BibleVersionRecord.self,
    ])
}
