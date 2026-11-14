import Foundation

struct LocatedDevotion: Equatable, Sendable {
    var language: String
    var title: String
}

/// Finds where a saved prayer or litany is on this device.
enum DevotionBookmarks {
    /// Opens the pack the item was saved from. The current UI language is not used.
    /// A row with no pack language falls back to installed packs in order.
    static func locate(
        type: String,
        id: String,
        language: String,
        packId: String = "",
        installed: Set<String>,
        load: (DevotionKind, String) -> DevotionBody? = { kind, code in
            DevotionReader.load(kind, language: code)
        }
    ) -> LocatedDevotion? {
        guard let kind = DevotionKind(rawValue: type), kind == .prayers || kind == .litanies else {
            return nil
        }
        let preferred = language.isEmpty
            ? BookmarkType.languageCode(packId: packId, type: type)
            : language
        for code in languages(preferred: preferred, type: type, installed: installed) {
            guard installed.contains("\(type)-\(code)") else { continue }
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

    private static func languages(preferred: String, type: String, installed: Set<String>) -> [String] {
        var order: [String] = []
        func add(_ code: String) {
            if !code.isEmpty, !order.contains(code) { order.append(code) }
        }
        if !preferred.isEmpty {
            add(preferred)
            return order
        }
        let prefix = "\(type)-"
        let others = installed.compactMap { pack -> String? in
            guard pack.hasPrefix(prefix) else { return nil }
            let code = String(pack.dropFirst(prefix.count))
            return code.isEmpty ? nil : code
        }
        .sorted { lhs, rhs in
            if lhs == PackLanguages.defaultCode { return true }
            if rhs == PackLanguages.defaultCode { return false }
            return lhs < rhs
        }
        others.forEach(add)
        return order
    }
}
