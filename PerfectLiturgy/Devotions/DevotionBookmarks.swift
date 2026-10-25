import Foundation
import SwiftData

/// A saved prayer, litany, or other non-hymn item. Hymns stay on `HymnBookmark`.
/// The key is `type|id`, matching the bookmark route.
@Model
final class DevotionBookmark {
    @Attribute(.unique) var key: String
    var type: String
    var itemId: String
    var titleSnapshot: String
    var language: String = ""
    var createdAt: Date

    init(type: String, itemId: String, titleSnapshot: String, language: String = "", createdAt: Date) {
        self.key = BookmarkType.key(type: type, id: itemId)
        self.type = type
        self.itemId = itemId
        self.titleSnapshot = titleSnapshot
        self.language = language
        self.createdAt = createdAt
    }
}

struct LocatedDevotion: Equatable, Sendable {
    var language: String
    var title: String
}

enum DevotionBookmarks {
    static func toggle(
        type: String,
        id: String,
        title: String,
        language: String,
        in context: ModelContext
    ) throws {
        if let bookmark = try fetch(type: type, id: id, in: context) {
            context.delete(bookmark)
        } else {
            context.insert(
                DevotionBookmark(
                    type: type,
                    itemId: id,
                    titleSnapshot: title,
                    language: language,
                    createdAt: .now
                )
            )
        }
        try context.save()
    }

    static func remove(type: String, id: String, in context: ModelContext) throws {
        guard let bookmark = try fetch(type: type, id: id, in: context) else { return }
        context.delete(bookmark)
        try context.save()
    }

    /// The stored language is the one that was open when it was saved.
    /// A row from the account has no language, so the first installed pack that contains the id is used.
    static func locate(
        type: String,
        id: String,
        language: String,
        installed: Set<String>,
        load: (DevotionKind, String) -> DevotionBody? = { kind, code in
            DevotionReader.load(kind, language: code)
        }
    ) -> LocatedDevotion? {
        guard let kind = DevotionKind(rawValue: type), kind == .prayers || kind == .litanies else {
            return nil
        }
        for code in languages(preferred: language, type: type, installed: installed) {
            guard let body = load(kind, code) else { continue }
            switch body {
            case .prayers(_, let prayers):
                if let prayer = prayers.first(where: { $0.id == id }) {
                    return LocatedDevotion(language: code, title: prayer.title)
                }
            case .litanies(_, let litanies):
                if let litany = litanies.first(where: { $0.id == id }) {
                    return LocatedDevotion(language: code, title: litany.title)
                }
            default:
                break
            }
        }
        return nil
    }

    private static func fetch(type: String, id: String, in context: ModelContext) throws -> DevotionBookmark? {
        let key = BookmarkType.key(type: type, id: id)
        let descriptor = FetchDescriptor<DevotionBookmark>(predicate: #Predicate { $0.key == key })
        return try context.fetch(descriptor).first
    }

    private static func languages(preferred: String, type: String, installed: Set<String>) -> [String] {
        if !preferred.isEmpty {
            return [preferred]
        }
        let prefix = "\(type)-"
        return installed.compactMap { pack -> String? in
            guard pack.hasPrefix(prefix) else { return nil }
            let code = String(pack.dropFirst(prefix.count))
            return code.isEmpty ? nil : code
        }
        .sorted { lhs, rhs in
            if lhs == PackLanguages.defaultCode { return true }
            if rhs == PackLanguages.defaultCode { return false }
            return lhs < rhs
        }
    }
}
