import CryptoKit
import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after a bookmark is saved or removed on this device. A signed-in app pushes the change.
    nonisolated static let bookmarksDidChange = Notification.Name("com.perfectliturgy.bookmarksDidChange")
}

/// Bookmarks removed on this device, with the time of removal.
///
/// The server keeps every bookmark it is sent and has no delete route. Without this list, the next merge
/// would read a removed bookmark back from the account and save it again. An account row is skipped when it
/// was made before the removal. A row saved again on another device is newer, so it comes back.
nonisolated enum BookmarkRemovals {
    static let storageKey = "bookmarks.removed"
    private static let limit = 500

    static func all(defaults: UserDefaults = .standard) -> [String: Int64] {
        guard let stored = defaults.dictionary(forKey: storageKey) else { return [:] }
        var result: [String: Int64] = [:]
        for (key, value) in stored {
            if let number = value as? NSNumber { result[key] = number.int64Value }
        }
        return result
    }

    static func mark(_ key: String, at date: Date = .now, defaults: UserDefaults = .standard) {
        var removals = all(defaults: defaults)
        removals[key] = Int64((date.timeIntervalSince1970 * 1000).rounded())
        if removals.count > limit {
            let newest = removals.sorted { $0.value > $1.value }.prefix(limit)
            removals = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
        }
        defaults.set(removals, forKey: storageKey)
    }

    static func clear(_ key: String, defaults: UserDefaults = .standard) {
        var removals = all(defaults: defaults)
        guard removals.removeValue(forKey: key) != nil else { return }
        defaults.set(removals, forKey: storageKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
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
            BookmarkRemovals.mark(bookmark.key, defaults: defaults)
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
