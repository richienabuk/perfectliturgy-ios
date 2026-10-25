import Foundation

/// The language chosen for each pack type. Hymns, Prayers and Litanies each keep their own.
///
/// A choice stays when a screen closes and when the app restarts. A type with no choice opens in
/// its default language, and Hymns opens on all languages. Choosing for one type never moves another.
@Observable
final class LanguageSelection {
    static let storageKey = "languageSelection"

    private let defaults: UserDefaults
    private var codes: [String: String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        codes = defaults.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
    }

    func code(for type: String) -> String? {
        codes[type]
    }

    func code(for kind: DevotionKind) -> String? {
        code(for: kind.rawValue)
    }

    /// Nil clears the choice, which is how Hymns goes back to all languages.
    func select(_ code: String?, for type: String) {
        guard codes[type] != code else { return }
        codes[type] = code
        defaults.set(codes, forKey: Self.storageKey)
    }

    func select(_ code: String?, for kind: DevotionKind) {
        select(code, for: kind.rawValue)
    }

    /// The language a saved prayer or litany opens in first. Hymns have none, because a hymn id is one language.
    func openCode(forBookmarkType type: String) -> String? {
        guard DevotionKind(rawValue: type) != nil else { return nil }
        return code(for: type) ?? PackLanguages.defaultCode
    }
}
