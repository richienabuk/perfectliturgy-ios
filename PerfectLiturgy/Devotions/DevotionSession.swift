import Foundation

/// Language chosen on a devotion screen. It lasts for this launch.
@Observable
final class DevotionSession {
    private var codes: [String: String] = [:]

    func code(for kind: DevotionKind) -> String? {
        codes[kind.rawValue]
    }

    func select(_ code: String, for kind: DevotionKind) {
        codes[kind.rawValue] = code
    }
}
