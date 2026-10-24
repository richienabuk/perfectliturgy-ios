import Foundation

/// `perfectliturgy://auth`, after Google or a magic link returns from the browser.
nonisolated enum AuthReturn {
    static func accepts(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "perfectliturgy" && url.host?.lowercased() == "auth"
    }

    /// Query or fragment. Token keys match the auth contract. An `error` value means the sign-in stopped.
    static func callback(from url: URL) -> AuthCallback? {
        guard accepts(url) else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        if let fragment = components?.fragment {
            var parsed = URLComponents()
            parsed.query = fragment
            items.append(contentsOf: parsed.queryItems ?? [])
        }
        if let token = token(in: items) {
            return .session(token: token)
        }
        if items.contains(where: { $0.name == "error" && ($0.value?.isEmpty == false) }) {
            return .failure
        }
        return nil
    }

    private static let tokenNames = ["session_token", "sessionToken", "token", "better-auth.session_token"]

    private static func token(in items: [URLQueryItem]) -> String? {
        for name in tokenNames {
            guard let value = items.first(where: { $0.name == name })?.value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}

nonisolated enum AuthCallback: Equatable, Sendable {
    case session(token: String)
    case failure
}
