import Foundation
import Security

/// The signed-in token, when one is already in the Keychain. Sign-in itself is a later phase.
@Observable
final class AppSession {
    private(set) var token: String?

    var isSignedIn: Bool {
        guard let token else { return false }
        return !token.isEmpty
    }

    init(token: String? = KeychainSession.token) {
        self.token = token
    }
}

enum KeychainSession {
    static let service = "com.perfectliturgy.session"
    static let account = "token"

    static var token: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        let value = String(data: data, encoding: .utf8)
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
