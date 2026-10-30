import Foundation
import SwiftData

enum PackInstallResult: Equatable, Sendable {
    case installed
    case needsSignIn
    case unavailable
    case connection
}

enum PackInstaller {
    static func catalog(
        client: PackClient,
        supportRoot: URL
    ) async -> [PackRecord] {
        do {
            let live = try await client.catalog()
            try? PackFiles.saveCatalog(live, root: supportRoot)
            return live
        } catch {
            if let stored = PackFiles.loadCatalog(root: supportRoot), !stored.packs.isEmpty {
                return stored.packs
            }
            return PackSeed.rows
        }
    }

    static func install(
        _ pack: PackRecord,
        client: PackClient,
        context: ModelContext,
        packs: InstalledPacks,
        supportRoot: URL,
        defaults: UserDefaults,
        bibleContainer: ModelContainer = BibleStore.shared
    ) async -> PackInstallResult {
        if pack.requiresSignIn, client.token?.isEmpty != false {
            return .needsSignIn
        }
        let data: Data
        do {
            data = try await client.download(packId: pack.packId)
        } catch let error as PackHTTPError {
            switch error {
            case .status(401), .status(403):
                return .needsSignIn
            case .status(404):
                return .unavailable
            default:
                return .connection
            }
        } catch {
            return .connection
        }
        do {
            try await apply(
                data,
                pack: pack,
                context: context,
                supportRoot: supportRoot,
                bibleContainer: bibleContainer
            )
        } catch let error as PackHTTPError {
            if case .status(404) = error { return .unavailable }
            return .connection
        } catch {
            return .connection
        }
        let revision = revision(in: data) ?? pack.revision
        PackFiles.storeRevision(revision, for: pack.packId, defaults: defaults)
        packs.install(pack.packId)
        return .installed
    }

    static func remove(
        _ pack: PackRecord,
        context: ModelContext,
        packs: InstalledPacks,
        supportRoot: URL,
        defaults: UserDefaults,
        bibleContainer: ModelContainer = BibleStore.shared
    ) async throws {
        if pack.type == "hymns", let language = languageCode(for: pack) {
            try HymnImporter.removeLanguage(language, in: context)
        }
        if pack.type == "readings" {
            try await BibleImporter(modelContainer: bibleContainer).removeVersion(packId: pack.packId)
        }
        if let kind = DevotionKind(rawValue: pack.type), let language = languageCode(for: pack) {
            DevotionReader.forget(kind, language: language)
        }
        let file = PackFiles.file(for: pack.packId, root: supportRoot)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        if pack.type == "calendar" {
            await LectionaryStore.shared.invalidate(id: pack.packId)
        }
        PackFiles.clearRevision(for: pack.packId, defaults: defaults)
        packs.remove(pack.packId)
    }

    static func languageCode(for pack: PackRecord) -> String? {
        if let language = pack.language, !language.isEmpty {
            return language
        }
        let parts = pack.packId.split(separator: "-", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let code = String(parts[1])
        return code.isEmpty ? nil : code
    }

    private static func apply(
        _ data: Data,
        pack: PackRecord,
        context: ModelContext,
        supportRoot: URL,
        bibleContainer: ModelContainer
    ) async throws {
        switch pack.type {
        case "hymns":
            try HymnImporter.importData(data, into: context)
        case "readings":
            let payload = try BiblePackReader.decode(data)
            try await BibleImporter(modelContainer: bibleContainer)
                .replaceVersion(payload: payload, displayName: pack.displayName)
        case "order", "rosary", "stations", "litanies", "prayers":
            guard
                let kind = DevotionKind(rawValue: pack.type),
                DevotionLibrary.decode(kind, data: data) != nil
            else {
                throw PackHTTPError.transport
            }
            try write(data, packId: pack.packId, root: supportRoot)
            if let language = languageCode(for: pack) {
                DevotionReader.forget(kind, language: language)
            }
        case "calendar":
            // Validate off the main actor — a full lectionary pack is large enough to stall the UI.
            _ = try await decodeCalendar(data)
            try write(data, packId: pack.packId, root: supportRoot)
            await LectionaryStore.shared.invalidate(id: pack.packId)
        default:
            throw PackHTTPError.status(404)
        }
    }

    private static func write(_ data: Data, packId: String, root: URL) throws {
        try PackFiles.ensureFolder(root)
        try data.write(to: PackFiles.file(for: packId, root: root), options: .atomic)
    }

    @concurrent
    private static func decodeCalendar(_ data: Data) async throws -> Lectionary {
        try CalendarPackReader.decode(data)
    }

    private static func revision(in data: Data) -> String? {
        struct Header: Decodable {
            var revision: String?
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(Header.self, from: data).revision
    }
}
