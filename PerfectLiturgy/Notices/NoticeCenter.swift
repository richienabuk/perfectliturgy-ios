import Foundation

enum DeviceMemory {
    static let tokenKey = "notices.fcmToken"
    static let accountKey = "notices.account"

    static func needsSend(token: String, accountID: String, defaults: UserDefaults) -> Bool {
        guard !token.isEmpty else { return false }
        let storedToken = defaults.string(forKey: tokenKey) ?? ""
        let storedAccount = defaults.string(forKey: accountKey) ?? ""
        return storedToken != token || storedAccount != accountID
    }

    static func remember(token: String, accountID: String, defaults: UserDefaults) {
        defaults.set(token, forKey: tokenKey)
        defaults.set(accountID, forKey: accountKey)
    }
}

struct DeviceClient {
    var transport: any PackTransport
    var apiBase: URL
    var bearer: String?

    func register(fcmToken: String) async throws {
        let url = apiBase.appending(path: "v1").appending(path: "devices")
        let body = try JSONEncoder().encode(DeviceBody(token: fcmToken))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer, !bearer.isEmpty {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            request.setValue("__Secure-neon-auth.session_token=\(bearer)", forHTTPHeaderField: "Cookie")
        }
        let (_, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.transport
        }
    }
}

private struct DeviceBody: Encodable {
    var token: String
    var platform = "ios"
}

@Observable
final class NoticeCenter {
    static let shared = NoticeCenter()

    var presented: ParishNotice?
    private(set) var fcmToken: String?
    var bearer: String?
    var accountID: String?
    var defaults: UserDefaults = .standard
    var client = DeviceClient(transport: LivePackTransport(), apiBase: ServiceOrigin.apiBaseURL, bearer: nil)

    func present(userInfo: [AnyHashable: Any]) {
        presented = NoticePayload.notice(from: userInfo)
    }

    func tokenArrived(_ token: String?) async {
        guard let token, !token.isEmpty else { return }
        fcmToken = token
        await sendIfNeeded()
    }

    /// A signed-out change does not register again. Sign-in sends the token with the session.
    func sessionChanged(accountID: String?, bearer: String?) async {
        self.bearer = bearer
        self.accountID = accountID
        client.bearer = bearer
        guard bearer?.isEmpty == false else { return }
        await sendIfNeeded()
    }

    private func sendIfNeeded() async {
        guard let fcmToken else { return }
        let account = bearer?.isEmpty == false ? (accountID ?? "") : ""
        guard DeviceMemory.needsSend(token: fcmToken, accountID: account, defaults: defaults) else { return }
        client.bearer = bearer
        do {
            try await client.register(fcmToken: fcmToken)
            DeviceMemory.remember(token: fcmToken, accountID: account, defaults: defaults)
        } catch {}
    }
}
