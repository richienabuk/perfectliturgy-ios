import CryptoKit
import Foundation
import Security

/// One mobile sign-in attempt. The start URL and magic-link body carry `state` and the S256 challenge.
/// The app keeps the verifier and posts it with the one-time `code` to `/auth/mobile/token`.
nonisolated struct AuthPKCE: Equatable, Sendable, Codable {
    var state: String
    var verifier: String
    var challenge: String

    static func make() -> AuthPKCE {
        let state = random(byteCount: 32)
        let verifier = random(byteCount: 64)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        return AuthPKCE(state: state, verifier: verifier, challenge: challenge)
    }

    private static func random(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "PKCE needs random bytes.")
        return Data(bytes).base64URLEncodedString()
    }
}

private nonisolated extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Remembers the open PKCE attempt so a magic-link return can finish after a restart.
enum AuthPKCEStore {
    private static let key = "account.pendingPKCE"

    static func save(_ pkce: AuthPKCE, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(pkce) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(defaults: UserDefaults = .standard) -> AuthPKCE? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AuthPKCE.self, from: data)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
