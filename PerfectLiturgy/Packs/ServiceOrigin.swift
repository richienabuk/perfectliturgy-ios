import Foundation

/// Content calls use `{API_BASE_URL}/v1/...`. Auth calls use `{AUTH_BASE_URL}/api/auth/...`.
enum ServiceOrigin {
    static let production = URL(string: "https://api.perfectliturgy.com")!

    static var apiBaseURL: URL {
        configured("APIBaseURL") ?? debugFallback
    }

    static var authBaseURL: URL {
        configured("AuthBaseURL") ?? debugFallback
    }

    static func url(from raw: String?) -> URL {
        guard let raw else { return production }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("https://"), let url = URL(string: trimmed) else { return production }
        return url
    }

    private static var debugFallback: URL {
        #if DEBUG
        URL(string: "https://perfectliturgyapi.richienabuk.top")!
        #else
        production
        #endif
    }

    private static func configured(_ key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("https://"), let url = URL(string: trimmed) else { return nil }
        return url
    }
}
