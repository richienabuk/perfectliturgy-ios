import CryptoKit
import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after a bookmark is saved or removed on this device. A signed-in app pushes the change.
    nonisolated static let bookmarksDidChange = Notification.Name("com.perfectliturgy.bookmarksDidChange")
}

/// Bookmarks removed on this device, with the time of removal and the row the account needs.
///
/// The account keeps a removed row and reads `deletedAt`. This list is what the next push sends, and it
/// stops an older save from coming back. A row saved again after the removal is newer, so it comes back.
nonisolated enum BookmarkRemovals {
    static let storageKey = "bookmarks.removed"
    private static let limit = 500

    /// Removal time in milliseconds, keyed by `type|id`.
    static func all(defaults: UserDefaults = .standard) -> [String: Int64] {
        load(defaults: defaults).mapValues(\.deletedAt)
    }

    /// Removals that can be sent. A time with no row, from an older install, is kept for merge only.
    static func pending(defaults: UserDefaults = .standard) -> [BookmarkDraft] {
        load(defaults: defaults).values.compactMap(\.draft)
    }

    static func mark(_ key: String, at date: Date = .now, defaults: UserDefaults = .standard) {
        var records = load(defaults: defaults)
        var record = records[key] ?? Record(type: "", id: "", titleSnapshot: "", createdAt: 0, deletedAt: 0)
        record.deletedAt = milliseconds(date)
        records[key] = record
        save(records, defaults: defaults)
    }

    static func mark(_ draft: BookmarkDraft, at date: Date = .now, defaults: UserDefaults = .standard) {
        var records = load(defaults: defaults)
        records[draft.key] = Record(
            type: draft.type,
            id: draft.id,
            titleSnapshot: draft.titleSnapshot,
            createdAt: draft.createdAt,
            deletedAt: draft.deletedAt ?? milliseconds(date)
        )
        save(records, defaults: defaults)
    }

    static func clear(_ key: String, defaults: UserDefaults = .standard) {
        var records = load(defaults: defaults)
        guard records.removeValue(forKey: key) != nil else { return }
        save(records, defaults: defaults)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    private struct Record {
        var type: String
        var id: String
        var titleSnapshot: String
        var createdAt: Int64
        var deletedAt: Int64

        var draft: BookmarkDraft? {
            guard !type.isEmpty, !id.isEmpty else { return nil }
            return BookmarkDraft(
                type: type,
                id: id,
                titleSnapshot: titleSnapshot,
                createdAt: createdAt,
                deletedAt: deletedAt
            )
        }
    }

    private static func load(defaults: UserDefaults) -> [String: Record] {
        guard let stored = defaults.dictionary(forKey: storageKey) else { return [:] }
        var records: [String: Record] = [:]
        for (key, value) in stored {
            if let row = value as? [String: Any] {
                records[key] = Record(
                    type: row["type"] as? String ?? "",
                    id: row["id"] as? String ?? "",
                    titleSnapshot: row["titleSnapshot"] as? String ?? "",
                    createdAt: integer(row["createdAt"]) ?? 0,
                    deletedAt: integer(row["deletedAt"]) ?? 0
                )
            } else if let deletedAt = integer(value) {
                records[key] = Record(type: "", id: "", titleSnapshot: "", createdAt: 0, deletedAt: deletedAt)
            }
        }
        return records
    }

    private static func save(_ records: [String: Record], defaults: UserDefaults) {
        var trimmed = records
        if trimmed.count > limit {
            let newest = trimmed.sorted { $0.value.deletedAt > $1.value.deletedAt }.prefix(limit)
            trimmed = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
        }
        let stored = trimmed.mapValues { record -> [String: Any] in
            [
                "type": record.type,
                "id": record.id,
                "titleSnapshot": record.titleSnapshot,
                "createdAt": NSNumber(value: record.createdAt),
                "deletedAt": NSNumber(value: record.deletedAt),
            ]
        }
        defaults.set(stored, forKey: storageKey)
    }

    private static func integer(_ value: Any?) -> Int64? {
        switch value {
        case let number as Int64: return number
        case let number as Int: return Int64(number)
        case let number as NSNumber: return number.int64Value
        case let number as Double: return Int64(number.rounded())
        default: return nil
        }
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}

/// Saved items are first in, first out. At 50, the next one saved replaces the oldest.
///
/// An item that is dropped is also written to the removal list, so the account copy
/// does not bring it back on the next merge.
enum BookmarkLimit {
    static let maximum = 50

    /// Removes the oldest items until at most `maximum` remain. Returns how many were removed.
    @discardableResult
    static func enforce(in context: ModelContext, defaults: UserDefaults = .standard) throws -> Int {
        let all = try context.fetch(FetchDescriptor<Bookmark>())
        let excess = all.count - maximum
        guard excess > 0 else { return 0 }

        let oldest = all.sorted { ($0.createdAt, $0.key) < ($1.createdAt, $1.key) }.prefix(excess)
        for bookmark in oldest {
            BookmarkRemovals.mark(Bookmarks.draft(of: bookmark), defaults: defaults)
            context.delete(bookmark)
        }
        try context.save()
        return excess
    }
}

/// A one-way form of an account id. Preferences keep this, so no id or email sits there in plain text.
nonisolated enum AccountFingerprint {
    static func of(_ accountID: String) -> String {
        SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// The account whose bookmarks are on this device. Bookmarks made while signed out have no owner yet.
nonisolated enum BookmarkOwner {
    static let storageKey = "bookmarks.owner"

    /// True when a different account owns the bookmarks here.
    static func isOtherAccount(_ accountID: String, defaults: UserDefaults = .standard) -> Bool {
        guard let stored = defaults.string(forKey: storageKey), !stored.isEmpty else { return false }
        // An earlier version stored the id itself. Treat that as the same account.
        return stored != AccountFingerprint.of(accountID) && stored != accountID
    }

    static func matches(_ accountID: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: storageKey) == AccountFingerprint.of(accountID)
    }

    static func set(_ accountID: String, defaults: UserDefaults = .standard) {
        defaults.set(AccountFingerprint.of(accountID), forKey: storageKey)
    }
}
