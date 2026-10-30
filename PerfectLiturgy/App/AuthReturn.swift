import Foundation

/// `perfectliturgy://auth`, after Google or a magic link returns from the browser.
nonisolated enum AuthReturn {
    static func accepts(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "perfectliturgy" && url.host?.lowercased() == "auth"
    }

    /// Query or fragment. Prefer a one-time `code` + `state`. A bare `session_token` is only for the
    /// review host. An `error` value means the sign-in stopped.
    static func callback(from url: URL) -> AuthCallback? {
        guard accepts(url) else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        if let fragment = components?.fragment {
            var parsed = URLComponents()
            parsed.query = fragment
            items.append(contentsOf: parsed.queryItems ?? [])
        }
        if let code = value("code", in: items), let state = value("state", in: items) {
            return .code(code: code, state: state)
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
            guard let value = value(name, in: items) else { continue }
            return value
        }
        return nil
    }

    private static func value(_ name: String, in items: [URLQueryItem]) -> String? {
        guard let raw = items.first(where: { $0.name == name })?.value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum AuthCallback: Equatable, Sendable {
    /// One-time code from `/auth/mobile`. Exchange with the stored PKCE verifier.
    case code(code: String, state: String)
    /// Review-host bridge only. Production mobile auth uses `code`.
    case session(token: String)
    case failure
}
