import Foundation
import SwiftData

/// Saving and removing bookmarks. Hymns, prayers, and litanies all go through here.
enum Bookmarks {
    static func fetch(type: String, id: String, packId: String, in context: ModelContext) throws -> Bookmark? {
        let key = BookmarkType.key(type: type, id: id, packId: packId)
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.key == key })
        return try context.fetch(descriptor).first
    }

    static func isSaved(type: String, id: String, packId: String, in bookmarks: [Bookmark]) -> Bool {
        bookmarks.contains { $0.type == type && $0.itemId == id && $0.packId == packId }
    }

    /// Saves the item, or removes it when it is already saved.
    static func toggle(
        type: String,
        id: String,
        title: String,
        language: String,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        let packId = BookmarkType.packId(type: type, language: language)
        if try fetch(type: type, id: id, packId: packId, in: context) != nil {
            try remove(type: type, id: id, packId: packId, in: context, defaults: defaults)
        } else {
            let draft = BookmarkDraft(
                type: type,
                id: id,
                packId: packId,
                titleSnapshot: BookmarkType.clippedTitle(title),
                createdAt: BookmarkSync.milliseconds(.now)
            )
            try insert(draft, in: context, defaults: defaults)
        }
    }

    static func remove(
        type: String,
        id: String,
        packId: String,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        guard let bookmark = try fetch(type: type, id: id, packId: packId, in: context) else { return }
        let draft = draft(of: bookmark)
        context.delete(bookmark)
        try context.save()
        BookmarkRemovals.mark(draft, defaults: defaults)
        BookmarkSync.changed()
    }

    /// Puts a removed bookmark back, with its first save time. Used by Undo.
    static func restore(_ draft: BookmarkDraft, in context: ModelContext, defaults: UserDefaults = .standard) throws {
        guard try fetch(type: draft.type, id: draft.id, packId: draft.packId, in: context) == nil else { return }
        try insert(draft, in: context, defaults: defaults)
    }

    /// The row as the account sends it.
    static func draft(of bookmark: Bookmark) -> BookmarkDraft {
        BookmarkDraft(
            type: bookmark.type,
            id: bookmark.itemId,
            packId: bookmark.packId,
            titleSnapshot: bookmark.titleSnapshot,
            createdAt: BookmarkSync.milliseconds(bookmark.createdAt)
        )
    }

    private static func insert(_ draft: BookmarkDraft, in context: ModelContext, defaults: UserDefaults) throws {
        guard !draft.packId.isEmpty else { return }
        context.insert(
            Bookmark(
                type: draft.type,
                itemId: draft.id,
                titleSnapshot: draft.titleSnapshot,
                packId: draft.packId,
                createdAt: Date(timeIntervalSince1970: Double(draft.createdAt) / 1000)
            )
        )
        try context.save()
        BookmarkRemovals.clear(draft.key, defaults: defaults)
        try BookmarkLimit.enforce(in: context, defaults: defaults)
        BookmarkSync.changed()
    }
}

/// Fills `packId` and rewrites keys for bookmarks saved before pack identity existed.
enum BookmarkMigration {
    static func backfillPackIds(in context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Bookmark>())
        var changed = false
        for bookmark in all {
            var packId = bookmark.packId
            if packId.isEmpty, !bookmark.language.isEmpty {
                packId = BookmarkType.packId(type: bookmark.type, language: bookmark.language)
            }
            guard !packId.isEmpty else { continue }
            let language = bookmark.language.isEmpty
                ? BookmarkType.languageCode(packId: packId, type: bookmark.type)
                : bookmark.language
            let key = BookmarkType.key(type: bookmark.type, id: bookmark.itemId, packId: packId)
            if bookmark.packId != packId || bookmark.key != key || bookmark.language != language {
                bookmark.packId = packId
                bookmark.language = language
                bookmark.key = key
                changed = true
            }
        }
        if changed {
            try context.save()
        }
    }
}
