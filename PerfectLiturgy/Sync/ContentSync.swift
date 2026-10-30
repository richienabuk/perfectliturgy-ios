import Foundation
import SwiftData

enum SyncOutcome: Equatable, Sendable {
    case current
    case needsSignIn
    case connection
}

struct SyncReport: Equatable, Sendable {
    var outcome: SyncOutcome
    var bookmarksKept: Bool
}

enum SyncCopy {
    static let title = "Sync"
    static let working = "Syncing hymns and readings."
    static let current = "Hymns and readings are up to date."
    static let connection = "Check the connection and try again."
    static let signIn = "Sign in to update hymns and readings."
    static let bookmarksNotSent = "Saved items did not sync. They stay on this device."
}

/// Wi-Fi, or a cellular path that is not marked expensive or constrained.
struct LinkKind: Equatable, Sendable {
    var online: Bool
    var metered: Bool

    static let wifi = LinkKind(online: true, metered: false)
    static let cellular = LinkKind(online: true, metered: true)
    static let offline = LinkKind(online: false, metered: true)

    var allowsAutoSync: Bool { online && !metered }
}

enum SyncPolicy {
    static func allowsAutomatic(enabled: Bool, link: LinkKind) -> Bool {
        enabled && link.allowsAutoSync
    }
}

enum ContentSync {
    static func liveIDs(installed: Set<String>, catalog: [PackRecord]) -> [String] {
        installed.filter { id in
            if let pack = catalog.first(where: { $0.packId == id }) {
                return pack.mode == "live" && (pack.type == "hymns" || pack.type == "readings")
            }
            return id.hasPrefix("hymns-") || id.hasPrefix("readings-")
        }
        .sorted()
    }

    /// Installed calendars whose catalog `revision` is ahead of the stored one.
    static func calendarsNeedingUpdate(
        installed: Set<String>,
        catalog: [PackRecord],
        defaults: UserDefaults
    ) -> [PackRecord] {
        catalog
            .filter { pack in
                pack.type == "calendar"
                    && pack.mode == "download"
                    && installed.contains(pack.packId)
                    && !pack.revision.isEmpty
                    && PackFiles.revision(for: pack.packId, defaults: defaults) != pack.revision
            }
            .sorted { $0.packId < $1.packId }
    }

    static func run(
        installed: Set<String>,
        catalog: [PackRecord],
        client: PackClient,
        context: ModelContext,
        packs: InstalledPacks,
        supportRoot: URL,
        defaults: UserDefaults,
        bibleContainer: ModelContainer = BibleStore.shared,
        mergeBookmarks: () async throws -> Void
    ) async -> SyncReport {
        guard client.token?.isEmpty == false else {
            return SyncReport(outcome: .needsSignIn, bookmarksKept: false)
        }
        var summary = SyncOutcome.current
        for id in liveIDs(installed: installed, catalog: catalog) {
            if Task.isCancelled { return SyncReport(outcome: .connection, bookmarksKept: false) }
            let pack = record(id: id, catalog: catalog)
            if pack.requiresSignIn, client.token?.isEmpty != false {
                summary = worse(summary, .needsSignIn)
                continue
            }
            guard let stored = PackFiles.revision(for: pack.packId, defaults: defaults), !stored.isEmpty else {
                continue
            }
            let step: SyncOutcome
            if pack.type == "readings" {
                step = await pullReadingsDelta(
                    pack,
                    since: stored,
                    client: client,
                    defaults: defaults,
                    bibleContainer: bibleContainer
                )
            } else {
                step = await pullDelta(
                    pack,
                    since: stored,
                    client: client,
                    context: context,
                    defaults: defaults
                )
            }
            summary = worse(summary, step)
        }
        for pack in calendarsNeedingUpdate(installed: installed, catalog: catalog, defaults: defaults) {
            if Task.isCancelled { return SyncReport(outcome: .connection, bookmarksKept: false) }
            if pack.requiresSignIn, client.token?.isEmpty != false {
                summary = worse(summary, .needsSignIn)
                continue
            }
            let step = await refreshCalendar(
                pack,
                client: client,
                context: context,
                packs: packs,
                supportRoot: supportRoot,
                defaults: defaults,
                bibleContainer: bibleContainer
            )
            summary = worse(summary, step)
        }
        var bookmarksKept = false
        if client.token?.isEmpty == false {
            do {
                try await mergeBookmarks()
            } catch {
                bookmarksKept = true
            }
        }
        return SyncReport(outcome: summary, bookmarksKept: bookmarksKept)
    }

    private static func refreshCalendar(
        _ pack: PackRecord,
        client: PackClient,
        context: ModelContext,
        packs: InstalledPacks,
        supportRoot: URL,
        defaults: UserDefaults,
        bibleContainer: ModelContainer
    ) async -> SyncOutcome {
        let result = await PackInstaller.install(
            pack,
            client: client,
            context: context,
            packs: packs,
            supportRoot: supportRoot,
            defaults: defaults,
            bibleContainer: bibleContainer
        )
        switch result {
        case .installed: return .current
        case .needsSignIn: return .needsSignIn
        case .unavailable, .connection: return .connection
        }
    }

    private static func pullDelta(
        _ pack: PackRecord,
        since: String,
        client: PackClient,
        context: ModelContext,
        defaults: UserDefaults
    ) async -> SyncOutcome {
        let data: Data
        do {
            data = try await client.sync(packId: pack.packId, since: since)
        } catch let error as PackHTTPError {
            return mapped(error)
        } catch {
            return .connection
        }
        do {
            switch pack.type {
            case "hymns":
                try HymnImporter.importData(data, into: context)
            default:
                return .current
            }
        } catch {
            return .connection
        }
        if let revision = revision(in: data), !revision.isEmpty {
            PackFiles.storeRevision(revision, for: pack.packId, defaults: defaults)
        }
        return .current
    }

    /// Applies every readings sync page, then stores `revision` only after the last page.
    private static func pullReadingsDelta(
        _ pack: PackRecord,
        since: String,
        client: PackClient,
        defaults: UserDefaults,
        bibleContainer: ModelContainer
    ) async -> SyncOutcome {
        var cursor: String?
        var lastRevision: String?
        let importer = BibleImporter(modelContainer: bibleContainer)
        repeat {
            if Task.isCancelled { return .connection }
            let data: Data
            do {
                data = try await client.sync(packId: pack.packId, since: since, cursor: cursor)
            } catch let error as PackHTTPError {
                return mapped(error)
            } catch {
                return .connection
            }
            let page: BiblePackPayload
            do {
                page = try BiblePackReader.decode(data)
            } catch {
                return .connection
            }
            do {
                try await importer.applyPage(payload: page, displayName: pack.displayName)
            } catch {
                return .connection
            }
            lastRevision = page.revision
            cursor = page.nextCursor
        } while cursor != nil
        if let lastRevision, !lastRevision.isEmpty {
            PackFiles.storeRevision(lastRevision, for: pack.packId, defaults: defaults)
        }
        return .current
    }

    private static func record(id: String, catalog: [PackRecord]) -> PackRecord {
        if let pack = catalog.first(where: { $0.packId == id }) { return pack }
        let type = id.hasPrefix("readings-") ? "readings" : "hymns"
        let language = id.split(separator: "-", maxSplits: 1).dropFirst().joined(separator: "-")
        return PackRecord(
            packId: id,
            type: type,
            language: language.isEmpty ? nil : language,
            displayName: id,
            requiresSignIn: true,
            mode: "live"
        )
    }

    private static func mapped(_ error: PackHTTPError) -> SyncOutcome {
        switch error {
        case .status(401), .status(403): .needsSignIn
        default: .connection
        }
    }

    private static func worse(_ current: SyncOutcome, _ next: SyncOutcome) -> SyncOutcome {
        if current == .connection || next == .connection { return .connection }
        if current == .needsSignIn || next == .needsSignIn { return .needsSignIn }
        return .current
    }

    private static func revision(in data: Data) -> String? {
        struct Header: Decodable { var revision: String? }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(Header.self, from: data).revision
    }
}
