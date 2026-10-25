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

    static func run(
        installed: Set<String>,
        catalog: [PackRecord],
        client: PackClient,
        context: ModelContext,
        packs: InstalledPacks,
        supportRoot: URL,
        defaults: UserDefaults,
        mergeBookmarks: () async throws -> Void,
        anchor: CivilDate = CivilDate(Date())
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
            let step = await pullDelta(
                pack,
                since: stored,
                client: client,
                context: context,
                defaults: defaults,
                anchor: anchor
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

    private static func pullDelta(
        _ pack: PackRecord,
        since: String,
        client: PackClient,
        context: ModelContext,
        defaults: UserDefaults,
        anchor: CivilDate
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
            case "readings":
                try BibleLibrary.applyDelta(data, pack: pack, into: context, anchor: anchor)
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
