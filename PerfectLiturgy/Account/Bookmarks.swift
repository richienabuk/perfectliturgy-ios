import Foundation
import SwiftData

/// Saving and removing bookmarks. Hymns, prayers, and litanies all go through here.
enum Bookmarks {
    static func fetch(type: String, id: String, in context: ModelContext) throws -> Bookmark? {
        let key = BookmarkType.key(type: type, id: id)
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.key == key })
        return try context.fetch(descriptor).first
    }

    static func isSaved(type: String, id: String, in bookmarks: [Bookmark]) -> Bool {
        bookmarks.contains { $0.type == type && $0.itemId == id }
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
        if try fetch(type: type, id: id, in: context) != nil {
            try remove(type: type, id: id, in: context, defaults: defaults)
        } else {
            let draft = BookmarkDraft(
                type: type,
                id: id,
                titleSnapshot: title,
                createdAt: BookmarkSync.milliseconds(.now)
            )
            try insert(draft, language: language, in: context, defaults: defaults)
        }
    }

    static func remove(type: String, id: String, in context: ModelContext, defaults: UserDefaults = .standard) throws {
        guard let bookmark = try fetch(type: type, id: id, in: context) else { return }
        let draft = draft(of: bookmark)
        context.delete(bookmark)
        try context.save()
        BookmarkRemovals.mark(draft, defaults: defaults)
        BookmarkSync.changed()
    }

    /// Puts a removed bookmark back, with its first save time. Used by Undo.
    static func restore(_ draft: BookmarkDraft, language: String, in context: ModelContext, defaults: UserDefaults = .standard) throws {
        guard try fetch(type: draft.type, id: draft.id, in: context) == nil else { return }
        try insert(draft, language: language, in: context, defaults: defaults)
    }

    /// The row as the account sends it.
    static func draft(of bookmark: Bookmark) -> BookmarkDraft {
        BookmarkDraft(
            type: bookmark.type,
            id: bookmark.itemId,
            titleSnapshot: bookmark.titleSnapshot,
            createdAt: BookmarkSync.milliseconds(bookmark.createdAt)
        )
    }

    private static func insert(_ draft: BookmarkDraft, language: String, in context: ModelContext, defaults: UserDefaults) throws {
        context.insert(
            Bookmark(
                type: draft.type,
                itemId: draft.id,
                titleSnapshot: draft.titleSnapshot,
                language: language,
                createdAt: Date(timeIntervalSince1970: Double(draft.createdAt) / 1000)
            )
        )
        try context.save()
        BookmarkRemovals.clear(draft.key, defaults: defaults)
        try BookmarkLimit.enforce(in: context, defaults: defaults)
        BookmarkSync.changed()
    }
}
