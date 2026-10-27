import Foundation
import SwiftData

enum AuthError: Error, Equatable {
    case rejected
    case appleUnavailable
    case cancelled
    case transport
}

struct ConfirmedSession: Equatable, Sendable {
    var token: String
    var profile: AccountProfile
}

/// Slugs the bookmark route accepts. `prayers` is special prayers.
nonisolated enum BookmarkType {
    static let hymns = "hymns"
    static let prayers = "prayers"
    static let litanies = "litanies"

    static func key(type: String, id: String) -> String {
        "\(type)|\(id)"
    }
}

nonisolated struct BookmarkDraft: Equatable, Sendable {
    var type: String
    var id: String
    var titleSnapshot: String
    var createdAt: Int64
    /// Milliseconds since epoch when this device, or the account, removed the item. Nil while it is saved.
    var deletedAt: Int64? = nil

    var key: String { BookmarkType.key(type: type, id: id) }
}

extension BookmarkDraft: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case titleSnapshot
        case createdAt
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        id = try container.decode(String.self, forKey: .id)
        titleSnapshot = try container.decodeIfPresent(String.self, forKey: .titleSnapshot) ?? ""
        createdAt = try Self.milliseconds(in: container, forKey: .createdAt) ?? 0
        deletedAt = try Self.milliseconds(in: container, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(titleSnapshot, forKey: .titleSnapshot)
        try container.encode(createdAt, forKey: .createdAt)
        // Null clears a removal. Omitting the key would leave the account row saved.
        try container.encode(deletedAt, forKey: .deletedAt)
    }

    private static func milliseconds(
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Int64? {
        guard container.contains(key), try container.decodeNil(forKey: key) == false else { return nil }
        if let value = try? container.decode(Int64.self, forKey: key) { return value }
        if let value = try? container.decode(Double.self, forKey: key) { return Int64(value.rounded()) }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected a timestamp in milliseconds."
        )
    }
}

/// Auth calls use `{AUTH_BASE_URL}/api/auth/...`. Bookmarks use `{API_BASE_URL}/v1/bookmarks`.
struct AuthClient {
    var transport: any PackTransport
    var authBase: URL
    var apiBase: URL

    static var live: AuthClient {
        AuthClient(
            transport: LivePackTransport(),
            authBase: ServiceOrigin.authBaseURL,
            apiBase: ServiceOrigin.apiBaseURL
        )
    }

    /// The browser must open this page so the session challenge cookie stays on that tab.
    func startURL(provider: String) -> URL {
        let base = authBase
            .appending(path: "auth")
            .appending(path: "mobile")
            .appending(path: "start")
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        components.queryItems = [URLQueryItem(name: "provider", value: provider)]
        return components.url ?? base
    }

    func currentSession(bearer: String) async throws -> ConfirmedSession {
        let url = authBase.appending(path: "api").appending(path: "auth").appending(path: "get-session")
        let (data, http) = try await send(authorized(url, bearer: bearer))
        // Only 401 means the session is gone. A 403 can come from a proxy or firewall, and must not sign anyone out.
        if http.statusCode == 401 { throw AuthError.rejected }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.transport }
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if body == nil || body?.isEmpty == true || body == "null" { throw AuthError.rejected }
        let fields = Self.fields(in: data)
        guard let email = fields.email else { throw AuthError.rejected }
        // The deep-link bearer is the signed session cookie. `session.token` in the
        // body is the unsigned database token, and Neon rejects that on pack download.
        let token = Self.signedCookie(in: http) ?? bearer
        guard !token.isEmpty else { throw AuthError.transport }
        return ConfirmedSession(
            token: token,
            profile: AccountProfile(id: fields.id ?? email, email: email, name: fields.name ?? "")
        )
    }

    func sendMagicLink(email: String) async throws {
        let url = authBase
            .appending(path: "api")
            .appending(path: "auth")
            .appending(path: "sign-in")
            .appending(path: "magic-link")
        let body = try JSONEncoder().encode(MagicLinkBody(email: email, callbackURL: "perfectliturgy://auth"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, http) = try await send(request)
        guard (200..<300).contains(http.statusCode) else { throw AuthError.transport }
    }

    /// Native Apple. A server that has no Apple provider returns no session token.
    func exchangeApple(identityToken: String, nonce: String) async throws -> String {
        let url = authBase
            .appending(path: "api")
            .appending(path: "auth")
            .appending(path: "sign-in")
            .appending(path: "social")
        let payload: [String: Any] = [
            "provider": "apple",
            "callbackURL": "perfectliturgy://auth",
            "disableRedirect": true,
            "idToken": [
                "token": identityToken,
                "nonce": nonce,
            ],
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, http) = try await send(request)
        guard (200..<300).contains(http.statusCode) else { throw AuthError.appleUnavailable }
        let fields = Self.fields(in: data)
        if let token = fields.token, !token.isEmpty { return token }
        if let header = Self.cookieHeader(in: http),
           let token = Self.cookieToken(in: header), !token.isEmpty {
            return token
        }
        throw AuthError.appleUnavailable
    }

    /// True when the server ended the session, or no longer knows it.
    @discardableResult
    func signOut(bearer: String) async -> Bool {
        let url = authBase.appending(path: "api").appending(path: "auth").appending(path: "sign-out")
        let body = Data("{}".utf8)
        var request = authorized(url, bearer: bearer, method: "POST", body: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let (_, http) = try? await send(request) else { return false }
        return (200..<300).contains(http.statusCode) || http.statusCode == 401
    }

    func pushBookmarks(_ rows: [BookmarkDraft], bearer: String) async throws -> [BookmarkDraft] {
        let url = apiBase.appending(path: "v1").appending(path: "bookmarks")
        let body = try JSONEncoder().encode(rows)
        let request = authorized(url, bearer: bearer, method: "PUT", body: body)
        let (data, http) = try await send(request)
        if http.statusCode == 401 || http.statusCode == 403 { throw AuthError.rejected }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.transport }
        return try Self.bookmarkRows(in: data)
    }

    func bookmarks(bearer: String) async throws -> [BookmarkDraft] {
        var page = 1
        var collected: [BookmarkDraft] = []
        var seen: Set<String> = []
        while page <= 30 {
            let envelope = try await bookmarkPage(page, bearer: bearer)
            for row in envelope.rows where seen.insert(row.key).inserted {
                collected.append(row)
            }
            if envelope.rows.isEmpty || envelope.finished || collected.count >= envelope.total {
                break
            }
            page += 1
        }
        return collected
    }

    private func bookmarkPage(_ page: Int, bearer: String) async throws -> BookmarkPage {
        let base = apiBase.appending(path: "v1").appending(path: "bookmarks")
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw AuthError.transport
        }
        components.queryItems = [URLQueryItem(name: "page", value: String(page))]
        guard let url = components.url else { throw AuthError.transport }
        let (data, http) = try await send(authorized(url, bearer: bearer))
        if http.statusCode == 401 || http.statusCode == 403 { throw AuthError.rejected }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.transport }
        return try Self.bookmarkPage(in: data)
    }

    private func authorized(_ url: URL, bearer: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("__Secure-neon-auth.session_token=\(bearer)", forHTTPHeaderField: "Cookie")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw AuthError.transport }
        return (data, http)
    }

    fileprivate static func fields(in data: Data) -> (id: String?, email: String?, name: String?, token: String?) {
        guard !data.isEmpty, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil, nil, nil)
        }
        let user = json["user"] as? [String: Any] ?? json
        let session = json["session"] as? [String: Any]
        let id = text(user["id"])
        let email = text(user["email"]) ?? text(json["email"])
        let name = text(user["name"]) ?? text(json["name"])
        var token = text(session?["token"]) ?? text(session?["sessionToken"]) ?? text(session?["session_token"])
        if token == nil { token = text(json["token"]) }
        if token == nil, let link = text(json["url"]) ?? text(json["redirect"]), let url = URL(string: link) {
            if case .session(let value) = AuthReturn.callback(from: url) {
                token = value
            }
        }
        return (id, email, name, token)
    }

    /// A refreshed signed cookie from `Set-Cookie`. The JSON session token is not this value.
    fileprivate static func signedCookie(in response: HTTPURLResponse) -> String? {
        guard let header = cookieHeader(in: response) else { return nil }
        guard let token = cookieToken(in: header), !token.isEmpty else { return nil }
        return token
    }

    fileprivate static func cookieHeader(in response: HTTPURLResponse) -> String? {
        if let value = response.value(forHTTPHeaderField: "Set-Cookie"), !value.isEmpty {
            return value
        }
        for (key, value) in response.allHeaderFields {
            guard String(describing: key).lowercased() == "set-cookie" else { continue }
            if let text = value as? String, !text.isEmpty { return text }
        }
        return nil
    }

    fileprivate static func cookieToken(in header: String) -> String? {
        guard let range = header.range(of: "session_token=") else { return nil }
        let rest = header[range.upperBound...]
        let end = rest.firstIndex(where: { $0 == ";" || $0 == "," || $0 == " " }) ?? rest.endIndex
        let value = String(rest[..<end])
        guard !value.isEmpty else { return nil }
        return value.removingPercentEncoding ?? value
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func bookmarkRows(in data: Data) throws -> [BookmarkDraft] {
        try bookmarkPage(in: data).rows
    }

    private static func bookmarkPage(in data: Data) throws -> BookmarkPage {
        if data.isEmpty { return BookmarkPage(rows: [], total: 0, finished: true) }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(BookmarkEnvelope.self, from: data) {
            let total = envelope.total ?? envelope.data.count
            return BookmarkPage(rows: envelope.data, total: total, finished: envelope.total == nil)
        }
        if let rows = try? decoder.decode([BookmarkDraft].self, from: data) {
            return BookmarkPage(rows: rows, total: rows.count, finished: true)
        }
        throw AuthError.transport
    }
}

private struct MagicLinkBody: Encodable {
    var email: String
    var callbackURL: String
}

private struct BookmarkEnvelope: Decodable {
    var data: [BookmarkDraft]
    var total: Int?
}

private struct BookmarkPage {
    var rows: [BookmarkDraft]
    var total: Int
    var finished: Bool
}

enum BookmarkSync {
    /// Saved rows, then removals the account has not been told about. A saved row wins over a removal of the same item.
    static func payload(_ bookmarks: [Bookmark], defaults: UserDefaults = .standard) -> [BookmarkDraft] {
        let saved = bookmarks.map(Bookmarks.draft(of:))
        let savedKeys = Set(saved.map(\.key))
        let removed = BookmarkRemovals.pending(defaults: defaults).filter { !savedKeys.contains($0.key) }
        return saved + removed
    }

    /// Tells a signed-in app to push a change. Posted after a bookmark is saved or removed here.
    static func changed() {
        NotificationCenter.default.post(name: .bookmarksDidChange, object: nil)
    }

    /// Inserts account rows this device does not have. A row with `deletedAt` is removed here.
    /// A local save newer than that removal stays. A removal on this device stays until a later save.
    static func merge(
        _ remote: [BookmarkDraft],
        into context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        var stored: [String: Bookmark] = [:]
        for bookmark in try context.fetch(FetchDescriptor<Bookmark>()) {
            stored[bookmark.key] = bookmark
        }
        var removals = BookmarkRemovals.all(defaults: defaults)
        for row in remote where !row.type.isEmpty && !row.id.isEmpty {
            if let deletedAt = row.deletedAt {
                let savedAt = stored[row.key].map { milliseconds($0.createdAt) }
                if let savedAt, savedAt > deletedAt {
                    BookmarkRemovals.clear(row.key, defaults: defaults)
                    removals[row.key] = nil
                    continue
                }
                if let local = stored.removeValue(forKey: row.key) {
                    context.delete(local)
                }
                if let existing = removals[row.key], existing > deletedAt { continue }
                var tombstone = row
                tombstone.deletedAt = deletedAt
                BookmarkRemovals.mark(tombstone, defaults: defaults)
                removals[row.key] = deletedAt
                continue
            }
            if let removedAt = removals[row.key] {
                if row.createdAt <= removedAt { continue }
                BookmarkRemovals.clear(row.key, defaults: defaults)
                removals[row.key] = nil
            }
            guard stored[row.key] == nil else { continue }
            let bookmark = Bookmark(
                type: row.type,
                itemId: row.id,
                titleSnapshot: row.titleSnapshot,
                language: "",
                createdAt: Date(timeIntervalSince1970: Double(row.createdAt) / 1000)
            )
            context.insert(bookmark)
            stored[row.key] = bookmark
        }
        if context.hasChanges {
            try context.save()
        }
        try BookmarkLimit.enforce(in: context, defaults: defaults)
    }

    static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
