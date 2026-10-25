import Foundation

/// One language a pack type can be read in. The names come from the pack list, never from the app.
nonisolated struct PackLanguage: Equatable, Hashable, Sendable, Identifiable {
    /// The pack id suffix, such as `efik` in `hymns-efik`.
    var code: String
    /// What the language control shows, such as `Efik`.
    var name: String
    /// The pack's own display name, such as `Efik Hymns`.
    var packName: String

    var id: String { code }
}

/// Reads languages off the pack list. The device locale has no part in this.
nonisolated enum PackLanguages {
    /// A pack type opens in this language until the person picks another.
    static let defaultCode = "en"

    static let hymnsType = "hymns"

    /// The catalog row for one pack: the id `type-code` first, then a row of that type and language.
    static func record(code: String, type: String, in catalog: [PackRecord]) -> PackRecord? {
        let id = "\(type)-\(code)"
        return catalog.first { $0.packId == id } ?? catalog.first { $0.type == type && $0.language == code }
    }

    /// A code the catalog does not list shows as the code itself.
    static func language(code: String, type: String, in catalog: [PackRecord]) -> PackLanguage {
        guard let record = record(code: code, type: type, in: catalog) else {
            return PackLanguage(code: code, name: code, packName: code)
        }
        return PackLanguage(code: code, name: record.languageLabel, packName: record.displayName)
    }

    /// The languages for these codes. The default language leads, then names in order.
    static func list(codes: some Sequence<String>, type: String, in catalog: [PackRecord]) -> [PackLanguage] {
        Set(codes)
            .map { language(code: $0, type: type, in: catalog) }
            .sorted { lhs, rhs in
                let left = lhs.code == defaultCode
                let right = rhs.code == defaultCode
                if left != right { return left }
                let order = lhs.name.localizedStandardCompare(rhs.name)
                if order != .orderedSame { return order == .orderedAscending }
                return lhs.code < rhs.code
            }
    }

    /// The language to read in: the one asked for while it is on the device, else the default, else the first.
    static func active(requested: String?, in languages: [PackLanguage]) -> PackLanguage? {
        if let requested, let match = languages.first(where: { $0.code == requested }) {
            return match
        }
        return languages.first { $0.code == defaultCode } ?? languages.first
    }
}
