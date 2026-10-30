import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import PerfectLiturgy

@Test func `auth links keep the session token from the query or the fragment`() throws {
    let encoded = try #require(URL(string: "perfectliturgy://auth?session_token=abc%2Bdef"))
    #expect(AuthReturn.callback(from: encoded) == .session(token: "abc+def"))
    let fragment = try #require(URL(string: "perfectliturgy://auth#session_token=from-mail"))
    #expect(AuthReturn.callback(from: fragment) == .session(token: "from-mail"))
    let code = try #require(URL(string: "perfectliturgy://auth?code=one-time&state=abc"))
    #expect(AuthReturn.callback(from: code) == .code(code: "one-time", state: "abc"))
    let other = try #require(URL(string: "perfectliturgy://donate"))
    #expect(!AuthReturn.accepts(other))
    #expect(AuthReturn.callback(from: other) == nil)
}

@Test func `get-session keeps the signed bearer and ignores the unsigned session token`() async throws {
    let kept = AuthScript()
    kept.enqueue(status: 200, body: Data("""
    {"user":{"id":"user_1","email":"ada@example.com","name":"Ada"},"session":{}}
    """.utf8))
    let base = URL(string: "https://api.example.test")!
    let client = AuthClient(transport: kept, authBase: base, apiBase: base)
    let session = try await client.currentSession(bearer: "from-link")
    #expect(session.token == "from-link")
    #expect(session.profile == AccountProfile(id: "user_1", email: "ada@example.com", name: "Ada"))
    let request = try #require(kept.requests.first)
    #expect(request.url?.path == "/api/auth/get-session")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer from-link")
    #expect(request.value(forHTTPHeaderField: "Cookie") == "__Secure-neon-auth.session_token=from-link")

    let unsigned = AuthScript()
    unsigned.enqueue(status: 200, body: Data("""
    {"id":"user_2","email":"ada@example.com","name":"Ada","session":{"token":"raw-db-token","sessionToken":"from-server"}}
    """.utf8))
    let second = AuthClient(transport: unsigned, authBase: base, apiBase: base)
    let confirmed = try await second.currentSession(bearer: "signed.cookie")
    #expect(confirmed.token == "signed.cookie")
    #expect(confirmed.profile.id == "user_2")

    let refreshed = AuthScript()
    refreshed.enqueue(
        status: 200,
        body: Data("""
        {"user":{"id":"user_3","email":"ada@example.com","name":"Ada"},"session":{"token":"raw-db-token"}}
        """.utf8),
        headers: ["Set-Cookie": "__Secure-neon-auth.session_token=refreshed.signature; Path=/; HttpOnly; Secure"]
    )
    let third = AuthClient(transport: refreshed, authBase: base, apiBase: base)
    let rotated = try await third.currentSession(bearer: "signed.cookie")
    #expect(rotated.token == "refreshed.signature")

    let missing = AuthScript()
    missing.enqueue(status: 200, body: Data("null\n".utf8))
    let rejected = AuthClient(transport: missing, authBase: base, apiBase: base)
    await #expect(throws: AuthError.rejected) {
        try await rejected.currentSession(bearer: "stale")
    }
}

@Test func `a rejected session clears the keychain and leaves bookmarks`() async throws {
    let service = "com.perfectliturgy.session.tests.\(UUID().uuidString)"
    let store = KeychainSessionStore(service: service)
    defer { store.clear() }
    try store.save("stale")
    let defaults = try #require(UserDefaults(suiteName: "account-\(UUID().uuidString)"))
    let session = AppSession(store: store, defaults: defaults)
    #expect(session.isSignedIn)
    let script = AuthScript()
    script.enqueue(status: 401, body: Data())
    let base = URL(string: "https://api.example.test")!
    await session.restore(client: AuthClient(transport: script, authBase: base, apiBase: base))
    #expect(!session.isSignedIn)
    #expect(store.token == nil)
    #expect(store.cachedAccount == nil)
}

@Test func `google starts in the browser and a magic link posts the callback`() async throws {
    let base = URL(string: "https://api.example.test")!
    let script = AuthScript()
    let client = AuthClient(transport: script, authBase: base, apiBase: base)
    let pkce = AuthPKCE.make()
    let start = client.startURL(provider: "google", pkce: pkce)
    #expect(start.path == "/auth/mobile/start")
    let items = URLComponents(url: start, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.first(where: { $0.name == "provider" })?.value == "google")
    #expect(items.first(where: { $0.name == "state" })?.value == pkce.state)
    #expect(items.first(where: { $0.name == "code_challenge" })?.value == pkce.challenge)
    #expect(items.first(where: { $0.name == "code_challenge_method" })?.value == "S256")

    script.enqueue(status: 200, body: Data())
    try await client.sendMagicLink(email: "ada@example.com", pkce: pkce)
    let request = try #require(script.requests.first)
    #expect(request.url?.path == "/api/auth/sign-in/magic-link")
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["email"] as? String == "ada@example.com")
    #expect(json["callbackURL"] as? String == "perfectliturgy://auth")
    #expect(json["state"] as? String == pkce.state)
    #expect(json["codeChallenge"] as? String == pkce.challenge)
    #expect(json["codeChallengeMethod"] as? String == "S256")
    #expect(!AccountEmail.isValid("ada"))
    #expect(AccountEmail.isValid("ada@example.com"))
}

@Test func `a mobile code exchanges for a session token`() async throws {
    let base = URL(string: "https://api.example.test")!
    let script = AuthScript()
    script.enqueue(status: 200, body: Data(#"{"token":"session-from-code"}"#.utf8))
    let client = AuthClient(transport: script, authBase: base, apiBase: base)
    let token = try await client.exchangeMobileCode(code: "one-time", state: "abc", verifier: "verifier")
    #expect(token == "session-from-code")
    let request = try #require(script.requests.first)
    #expect(request.url?.path == "/auth/mobile/token")
    #expect(request.httpMethod == "POST")
    let json = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
    #expect(json["code"] as? String == "one-time")
    #expect(json["state"] as? String == "abc")
    #expect(json["codeVerifier"] as? String == "verifier")

    let defaults = try #require(UserDefaults(suiteName: "pkce-redeem-\(UUID().uuidString)"))
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    let pkce = AuthPKCE(state: "abc", verifier: "verifier", challenge: "challenge")
    session.remember(pkce)
    let redeem = AuthScript()
    redeem.enqueue(status: 200, body: Data(#"{"token":"session-from-code"}"#.utf8))
    redeem.enqueue(status: 200, body: Data("""
    {"user":{"id":"user_1","email":"ada@example.com","name":"Ada"},"session":{}}
    """.utf8))
    redeem.enqueue(status: 200, body: Data(#"{"data":[],"page":1,"pageSize":50,"total":0}"#.utf8))
    redeem.enqueue(status: 200, body: Data(#"{"data":[],"page":1,"pageSize":50,"total":0}"#.utf8))
    let container = try HymnStore.make(inMemory: true)
    let link = try #require(URL(string: "perfectliturgy://auth?code=one-time&state=abc"))
    session.prepare(.google)
    await session.accept(
        link,
        client: AuthClient(transport: redeem, authBase: base, apiBase: base),
        context: container.mainContext,
        trusted: true
    )
    #expect(session.isSignedIn)
    #expect(session.token == "session-from-code")
    #expect(session.method == .google)
    #expect(AuthPKCEStore.load(defaults: defaults) == nil)
}

@Test func `a sent magic link asks the reader to check email and does not sign in`() async throws {
    let base = URL(string: "https://api.example.test")!
    let sent = AuthScript()
    sent.enqueue(status: 200, body: Data())
    let defaults = try #require(UserDefaults(suiteName: "magic-sent-\(UUID().uuidString)"))
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    await session.sendMagicLink(
        email: "ada@example.com",
        client: AuthClient(transport: sent, authBase: base, apiBase: base)
    )
    #expect(session.notice == AccountCopy.magicLinkSent)
    #expect(!session.isSignedIn)

    let refused = AuthScript()
    refused.enqueue(status: 400, body: Data(#"{"message":"Invalid email address"}"#.utf8))
    let failed = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    await failed.sendMagicLink(
        email: "ada@example.com",
        client: AuthClient(transport: refused, authBase: base, apiBase: base)
    )
    #expect(failed.notice == AccountCopy.connection)
    #expect(!failed.isSignedIn)
}

@Test func `apple is stored only when the server returns a session`() async throws {
    let base = URL(string: "https://api.example.test")!
    let refused = AuthScript()
    refused.enqueue(status: 404, body: Data(#"{"message":"provider"}"#.utf8))
    let client = AuthClient(transport: refused, authBase: base, apiBase: base)
    await #expect(throws: AuthError.appleUnavailable) {
        try await client.exchangeApple(identityToken: "jwt", nonce: "nonce")
    }

    let accepted = AuthScript()
    accepted.enqueue(
        status: 200,
        body: Data(#"{"token":"apple-session"}"#.utf8),
        headers: ["Set-Cookie": "__Secure-neon-auth.session_token=from-cookie"]
    )
    let ready = AuthClient(transport: accepted, authBase: base, apiBase: base)
    let token = try await ready.exchangeApple(identityToken: "jwt", nonce: "nonce")
    #expect(token == "apple-session")
    let request = try #require(accepted.requests.first)
    let payload = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
    #expect(payload["provider"] as? String == "apple")
    let idToken = try #require(payload["idToken"] as? [String: Any])
    #expect(idToken["token"] as? String == "jwt")
    #expect(idToken["nonce"] as? String == "nonce")

    let cookieOnly = AuthScript()
    cookieOnly.enqueue(status: 200, body: Data("{}".utf8), headers: ["Set-Cookie": "better-auth.session_token=from-cookie; Path=/"])
    let cookieClient = AuthClient(transport: cookieOnly, authBase: base, apiBase: base)
    #expect(try await cookieClient.exchangeApple(identityToken: "jwt", nonce: "nonce") == "from-cookie")
}

@Test func `a bookmark made while signed out joins the account and stays after sign-out`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let created = Date(timeIntervalSince1970: 1_729_000_000)
    context.insert(Bookmark(type: BookmarkType.hymns, itemId: "local-hymn", titleSnapshot: "Test hymn one", language: "en", createdAt: created))
    try context.save()

    let script = AuthScript()
    script.enqueue(status: 200, body: Data("""
    {"user":{"id":"user_1","email":"ada@example.com","name":"Ada"},"session":{"token":"session-1"}}
    """.utf8))
    script.enqueue(status: 200, body: Data("""
    {"data":[{"type":"hymns","id":"local-hymn","titleSnapshot":"Test hymn one","createdAt":1729000000000},{"type":"hymns","id":"remote-hymn","titleSnapshot":"Test hymn two","createdAt":1729000001000}],"page":1,"pageSize":2,"total":2}
    """.utf8))
    script.enqueue(status: 200, body: Data("""
    {"data":[{"type":"hymns","id":"local-hymn","titleSnapshot":"Server title","createdAt":1729000000000},{"type":"hymns","id":"remote-hymn","titleSnapshot":"Test hymn two","createdAt":1729000001000}],"page":1,"pageSize":2,"total":2}
    """.utf8))

    let defaults = try #require(UserDefaults(suiteName: "merge-\(UUID().uuidString)"))
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    let base = URL(string: "https://api.example.test")!
    let client = AuthClient(transport: script, authBase: base, apiBase: base)
    let link = try #require(URL(string: "perfectliturgy://auth?session_token=from-link"))
    session.prepare(.google)
    await session.accept(link, client: client, context: context, trusted: true)

    #expect(session.isSignedIn)
    #expect(session.token == "from-link")
    #expect(session.profile?.email == "ada@example.com")
    #expect(session.method == .google)
    let put = try #require(script.requests.first { $0.httpMethod == "PUT" })
    let sent = try JSONDecoder().decode([BookmarkDraft].self, from: put.httpBody ?? Data())
    #expect(sent.map(\.type) == ["hymns"])
    #expect(sent.map(\.id) == ["local-hymn"])
    #expect(sent.map(\.titleSnapshot) == ["Test hymn one"])
    #expect(sent.map(\.createdAt) == [1_729_000_000_000])
    #expect(put.value(forHTTPHeaderField: "Authorization") == "Bearer from-link")

    let stored = try context.fetch(FetchDescriptor<Bookmark>()).sorted { $0.itemId < $1.itemId }
    #expect(stored.map(\.itemId) == ["local-hymn", "remote-hymn"])
    #expect(stored.first { $0.itemId == "local-hymn" }?.titleSnapshot == "Test hymn one")

    let failing = AuthScript()
    failing.fail = true
    await session.signOut(client: AuthClient(transport: failing, authBase: base, apiBase: base))
    #expect(!session.isSignedIn)
    #expect(session.token == nil)
    let after = try context.fetch(FetchDescriptor<Bookmark>())
    #expect(Set(after.map(\.itemId)) == ["local-hymn", "remote-hymn"])
}

@Test func `a prayer and a litany join the account with their type`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let created = Date(timeIntervalSince1970: 1_729_000_000)
    context.insert(
        Bookmark(
            type: BookmarkType.prayers,
            itemId: "test-one",
            titleSnapshot: "Test prayer one",
            language: "en",
            createdAt: created
        )
    )
    try context.save()

    let script = AuthScript()
    script.enqueue(status: 200, body: Data("""
    {"user":{"id":"user_1","email":"ada@example.com","name":"Ada"},"session":{"token":"session-1"}}
    """.utf8))
    script.enqueue(status: 200, body: Data("""
    {"data":[{"type":"prayers","id":"test-one","titleSnapshot":"Test prayer one","createdAt":1729000000000},{"type":"litanies","id":"saints","titleSnapshot":"Test litany one","createdAt":1729000001000}],"page":1,"pageSize":2,"total":2}
    """.utf8))
    script.enqueue(status: 200, body: Data("""
    {"data":[{"type":"prayers","id":"test-one","titleSnapshot":"Test prayer one","createdAt":1729000000000},{"type":"litanies","id":"saints","titleSnapshot":"Test litany one","createdAt":1729000001000}],"page":1,"pageSize":2,"total":2}
    """.utf8))

    let defaults = try #require(UserDefaults(suiteName: "merge-devotion-\(UUID().uuidString)"))
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    let base = URL(string: "https://api.example.test")!
    let client = AuthClient(transport: script, authBase: base, apiBase: base)
    let link = try #require(URL(string: "perfectliturgy://auth?session_token=from-link"))
    session.prepare(.google)
    await session.accept(link, client: client, context: context, trusted: true)

    let put = try #require(script.requests.first { $0.httpMethod == "PUT" })
    let sent = try JSONDecoder().decode([BookmarkDraft].self, from: put.httpBody ?? Data())
    #expect(sent.map(\.type) == ["prayers"])
    #expect(sent.map(\.id) == ["test-one"])
    #expect(sent.map(\.titleSnapshot) == ["Test prayer one"])
    #expect(sent.map(\.createdAt) == [1_729_000_000_000])
    let fields = try #require(JSONSerialization.jsonObject(with: put.httpBody ?? Data()) as? [[String: Any]])
    #expect(fields.first?["hymnId"] == nil)

    let stored = try context.fetch(FetchDescriptor<Bookmark>()).sorted { $0.itemId < $1.itemId }
    #expect(stored.map(\.type) == ["litanies", "prayers"])
    #expect(stored.map(\.itemId) == ["saints", "test-one"])
    #expect(stored.first { $0.itemId == "test-one" }?.titleSnapshot == "Test prayer one")
    #expect(stored.first { $0.itemId == "saints" }?.language == "")
}

@Test func `a gated pack downloads only while signed in and sign-out leaves the body`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let defaults = UserDefaults(suiteName: "gate-account-\(UUID().uuidString)")!
    let packs = InstalledPacks(defaults: defaults)
    let root = FileManager.default.temporaryDirectory.appending(path: "account-packs-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let body = Data("""
    {"pack_id":"order-es","type":"order","language":"es","revision":"2026-10-01T12:00:00.000Z","data":[{"order":1,"title":"Test part","items":[{"order":1,"title":"Test item","text":"Test prayer one"}]}]}
    """.utf8)
    let spanish = PackRecord(packId: "order-es", type: "order", language: "es", displayName: "Order of Mass", mode: "download")
    let transport = DownloadScript(body: body)
    let signedIn = PackClient(transport: transport, apiBase: ServiceOrigin.production, token: "session-1")
    let installed = await PackInstaller.install(
        spanish,
        client: signedIn,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(installed == .installed)
    #expect(transport.downloadCount == 1)
    #expect(transport.authorization == "Bearer session-1")
    let file = PackFiles.file(for: "order-es", root: root)
    #expect(FileManager.default.fileExists(atPath: file.path))

    let session = AppSession(token: "session-1", store: MemorySessionStore(), defaults: defaults)
    await session.signOut(client: AuthClient(transport: AuthScript(), authBase: ServiceOrigin.production, apiBase: ServiceOrigin.production))
    #expect(!session.isSignedIn)
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(packs.contains("order-es"))

    let french = PackRecord(packId: "order-fr", type: "order", language: "fr", displayName: "Order of Mass", mode: "download")
    let blocked = PackClient(transport: transport, apiBase: ServiceOrigin.production, token: session.token)
    let refused = await PackInstaller.install(
        french,
        client: blocked,
        context: container.mainContext,
        packs: packs,
        supportRoot: root,
        defaults: defaults
    )
    #expect(refused == .needsSignIn)
    #expect(transport.downloadCount == 1)
    #expect(!FileManager.default.fileExists(atPath: PackFiles.file(for: "order-fr", root: root).path))
    #expect(FileManager.default.fileExists(atPath: file.path))
}

@Test func `bundled english and latin still open with no session`() throws {
    let defaults = try #require(UserDefaults(suiteName: "bundle-\(UUID().uuidString)"))
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    #expect(!session.isSignedIn)
    let bundle = Bundle(for: DesignPreferences.self)
    let root = FileManager.default.temporaryDirectory.appending(path: "bundle-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let english = DevotionLibrary.load(.order, language: "en", bundle: bundle, supportRoot: root)
    let latin = DevotionLibrary.load(.order, language: "la", bundle: bundle, supportRoot: root)
    guard case .order = english, case .order = latin else {
        Issue.record("Bundled English and Latin Order of Mass did not open.")
        return
    }
    #expect(HymnBundles.url(for: "hymns_en_catalogue", in: bundle) != nil)
    #expect(HymnBundles.url(for: "hymns_la_catalogue", in: bundle) != nil)
}

@Test func `sign-out still clears the session when the network fails`() async throws {
    let store = MemorySessionStore()
    try store.save("session-1")
    let defaults = try #require(UserDefaults(suiteName: "signout-\(UUID().uuidString)"))
    store.saveCachedAccount(#"{"profile":{"id":"user_1","email":"ada@example.com","name":"Ada"},"method":"email"}"#)
    let session = AppSession(store: store, defaults: defaults)
    #expect(session.profile?.email == "ada@example.com")
    let script = AuthScript()
    script.fail = true
    let base = URL(string: "https://api.example.test")!
    await session.signOut(client: AuthClient(transport: script, authBase: base, apiBase: base))
    #expect(session.token == nil)
    #expect(session.profile == nil)
    #expect(store.token == nil)
}

@Test func `the keychain keeps the session token until sign-out`() throws {
    let service = "com.perfectliturgy.session.tests.\(UUID().uuidString)"
    defer { KeychainSession.clear(service: service, account: KeychainSession.account) }
    try KeychainSession.save("session-1", service: service)
    #expect(KeychainSession.read(service: service, account: KeychainSession.account) == "session-1")
    try KeychainSession.save("session-2", service: service)
    #expect(KeychainSession.read(service: service, account: KeychainSession.account) == "session-2")
    KeychainSession.clear(service: service, account: KeychainSession.account)
    #expect(KeychainSession.read(service: service, account: KeychainSession.account) == nil)
}

@Test func `saved item counts stay plain`() {
    #expect(AccountCopy.savedDetail(count: 0) == "Nothing saved on this device.")
    #expect(AccountCopy.savedDetail(count: 1) == "1 item · stored on this device.")
    #expect(AccountCopy.savedDetail(count: 3) == "3 items · stored on this device.")
}

@Test func `the account screen offers google apple and email`() async throws {
    let defaults = try #require(UserDefaults(suiteName: "account-ui-\(UUID().uuidString)"))
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    AppFonts.register(bundle: Bundle(for: DesignPreferences.self))
    let view = AccountView()
        .modelContainer(try HymnStore.make(inMemory: true))
        .environment(AppNavigation())
        .environment(session)
        .resolvePalette()
        .frame(width: 390, height: 900)
    let image = try await renderAccount(view, size: CGSize(width: 390, height: 900))
    Attachment.record(image, named: "account-signed-out")
    #expect(image.size.width > 300)

    let signedDefaults = try #require(UserDefaults(suiteName: "account-ui-in-\(UUID().uuidString)"))
    let profile = AccountProfile(id: "user_1", email: "alex@example.com", name: "Alex")
    let signedStore = MemorySessionStore()
    AccountCache(store: signedStore, defaults: signedDefaults).save(profile: profile, method: .google)
    let signed = AppSession(token: "session-1", store: signedStore, defaults: signedDefaults)
    let signedView = AccountView()
        .modelContainer(try HymnStore.make(inMemory: true))
        .environment(AppNavigation())
        .environment(signed)
        .resolvePalette()
        .frame(width: 390, height: 900)
    let signedImage = try await renderAccount(signedView, size: CGSize(width: 390, height: 900))
    Attachment.record(signedImage, named: "account-signed-in")
    #expect(signedImage.size.height > 700)
}

private final class AuthScript: PackTransport {
    struct Reply {
        var status: Int
        var body: Data
        var headers: [String: String]
    }

    var replies: [Reply] = []
    var requests: [URLRequest] = []
    var fail = false

    func enqueue(status: Int, body: Data, headers: [String: String] = [:]) {
        replies.append(Reply(status: status, body: body, headers: headers))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if fail { throw URLError(.notConnectedToInternet) }
        let reply = replies.isEmpty ? Reply(status: 500, body: Data(), headers: [:]) : replies.removeFirst()
        let url = request.url ?? URL(string: "https://api.example.test")!
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!
        return (reply.body, response)
    }
}

private final class DownloadScript: PackTransport {
    var body: Data
    var downloadCount = 0
    var authorization: String?

    init(body: Data) {
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        downloadCount += 1
        authorization = request.value(forHTTPHeaderField: "Authorization")
        let url = request.url ?? ServiceOrigin.production
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

@MainActor
private func renderAccount<V: View>(_ view: V, size: CGSize) async throws -> UIImage {
    let host = UIHostingController(rootView: view)
    host.view.bounds = CGRect(origin: .zero, size: size)
    host.view.frame = CGRect(origin: .zero, size: size)
    let window = UIWindow(frame: host.view.bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(400))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
        host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
}
