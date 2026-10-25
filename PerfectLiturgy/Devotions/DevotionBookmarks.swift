import Foundation

struct LocatedDevotion: Equatable, Sendable {
    var language: String
    var title: String
}

/// Finds where a saved prayer or litany is on this device.
enum DevotionBookmarks {
    /// The language the reader has open now comes first, so a saved item opens where the reader is
    /// and the language choice stays as it was. Next is the language it was saved in.
    /// A row from the account has no language, so the installed packs are tried in order.
    static func locate(
        type: String,
        id: String,
        language: String,
        current: String? = nil,
        installed: Set<String>,
        load: (DevotionKind, String) -> DevotionBody? = { kind, code in
            DevotionReader.load(kind, language: code)
        }
    ) -> LocatedDevotion? {
        guard let kind = DevotionKind(rawValue: type), kind == .prayers || kind == .litanies else {
            return nil
        }
        for code in languages(preferred: language, current: current, type: type, installed: installed) {
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

    private static func languages(preferred: String, current: String?, type: String, installed: Set<String>) -> [String] {
        var order: [String] = []
        func add(_ code: String) {
            if !code.isEmpty, !order.contains(code) { order.append(code) }
        }
        let prefix = "\(type)-"
        if let current, installed.contains(prefix + current) {
            add(current)
        }
        if !preferred.isEmpty {
            add(preferred)
            return order
        }
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
