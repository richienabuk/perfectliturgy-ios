import Foundation
import SwiftData
import Testing
@testable import PerfectLiturgy

private final class ReplyScript: PackTransport {
    struct Reply {
        var status: Int
        var body: Data
    }

    var replies: [Reply] = []
    var requests: [URLRequest] = []

    func enqueue(status: Int = 200, _ body: String = "") {
        replies.append(Reply(status: status, body: Data(body.utf8)))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let reply = replies.isEmpty ? Reply(status: 500, body: Data()) : replies.removeFirst()
        let url = request.url ?? URL(string: "https://api.example.test")!
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        return (reply.body, response)
    }
}

private let base = URL(string: "https://api.example.test")!
private let emptyList = #"{"data":[],"page":1,"pageSize":0,"total":0}"#
private let adaSession = #"{"user":{"id":"user_1","email":"ada@example.com","name":"Ada"},"session":{}}"#

private func freshDefaults() throws -> UserDefaults {
    let defaults = try #require(UserDefaults(suiteName: "review-\(UUID().uuidString)"))
    return defaults
}

// MARK: Bookmarks

@Test func `a removed bookmark is sent with the time it was removed`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let created = Date(timeIntervalSince1970: 1_729_000_000)
    context.insert(Bookmark(type: BookmarkType.prayers, itemId: "test-one", titleSnapshot: "Test prayer one", language: "en", createdAt: created))
    try context.save()
    try Bookmarks.remove(type: BookmarkType.prayers, id: "test-one", in: context, defaults: defaults)

    let sent = BookmarkSync.payload(try context.fetch(FetchDescriptor<Bookmark>()), defaults: defaults)
    let row = try #require(sent.first)
    #expect(sent.count == 1)
    #expect(row.type == BookmarkType.prayers)
    #expect(row.id == "test-one")
    #expect(row.titleSnapshot == "Test prayer one")
    #expect(row.createdAt == 1_729_000_000_000)
    let removedAt = try #require(row.deletedAt)
    #expect(removedAt >= row.createdAt)

    let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(sent)) as? [[String: Any]])
    #expect(body.first?["deletedAt"] as? NSNumber != nil)
}

@Test func `a saved bookmark is sent with an empty removal time`() throws {
    let draft = BookmarkDraft(
        type: BookmarkType.hymns,
        id: "local-hymn",
        titleSnapshot: "Test hymn one",
        createdAt: 1_729_000_000_000
    )
    let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode([draft])) as? [[String: Any]])
    #expect(body.first?["deletedAt"] is NSNull)
}

@Test func `an account removal drops the bookmark on this device`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let created = Date(timeIntervalSince1970: 1_729_000_000)
    context.insert(Bookmark(type: BookmarkType.hymns, itemId: "test-one", titleSnapshot: "Test hymn one", language: "en", createdAt: created))
    try context.save()

    let removed = BookmarkDraft(
        type: BookmarkType.hymns,
        id: "test-one",
        titleSnapshot: "Test hymn one",
        createdAt: BookmarkSync.milliseconds(created),
        deletedAt: BookmarkSync.milliseconds(created) + 5_000
    )
    try BookmarkSync.merge([removed], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)

    let stale = BookmarkDraft(
        type: BookmarkType.hymns,
        id: "test-one",
        titleSnapshot: "Test hymn one",
        createdAt: BookmarkSync.milliseconds(created)
    )
    try BookmarkSync.merge([stale], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)
}

@Test func `a later save on this device keeps a bookmark the account removed`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let created = Date(timeIntervalSince1970: 1_729_000_000)
    context.insert(Bookmark(type: BookmarkType.litanies, itemId: "saints", titleSnapshot: "Test litany one", language: "en", createdAt: created.addingTimeInterval(10)))
    try context.save()
    let removed = BookmarkDraft(
        type: BookmarkType.litanies,
        id: "saints",
        titleSnapshot: "Test litany one",
        createdAt: BookmarkSync.milliseconds(created),
        deletedAt: BookmarkSync.milliseconds(created) + 1_000
    )
    try BookmarkSync.merge([removed], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).map(\.itemId) == ["saints"])
    #expect(BookmarkRemovals.pending(defaults: defaults).isEmpty)
}

@Test func `a removed bookmark stays removed until it is saved again`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    try Bookmarks.toggle(type: BookmarkType.prayers, id: "test-one", title: "Test prayer one", language: "en", in: context, defaults: defaults)
    try Bookmarks.toggle(type: BookmarkType.prayers, id: "test-one", title: "Test prayer one", language: "en", in: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)

    let removedAt = try #require(BookmarkRemovals.all(defaults: defaults)["prayers|test-one"])
    let older = BookmarkDraft(type: BookmarkType.prayers, id: "test-one", titleSnapshot: "Test prayer one", createdAt: removedAt - 5_000)
    try BookmarkSync.merge([older], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)

    let newer = BookmarkDraft(type: BookmarkType.prayers, id: "test-one", titleSnapshot: "Test prayer one", createdAt: removedAt + 5_000)
    try BookmarkSync.merge([newer], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).map(\.itemId) == ["test-one"])
    #expect(BookmarkRemovals.all(defaults: defaults).isEmpty)
}

@Test func `saving a bookmark again clears its removal`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    BookmarkRemovals.mark("litanies|saints", defaults: defaults)
    try Bookmarks.toggle(type: BookmarkType.litanies, id: "saints", title: "Test litany one", language: "en", in: context, defaults: defaults)
    #expect(BookmarkRemovals.all(defaults: defaults).isEmpty)
}

@Test func `undo puts a removed bookmark back with its first save time`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let created = Date(timeIntervalSince1970: 1_729_000_000)
    context.insert(Bookmark(type: BookmarkType.prayers, itemId: "test-one", titleSnapshot: "Test prayer one", language: "en", createdAt: created))
    try context.save()
    let draft = BookmarkDraft(type: BookmarkType.prayers, id: "test-one", titleSnapshot: "Test prayer one", createdAt: BookmarkSync.milliseconds(created))
    try Bookmarks.remove(type: BookmarkType.prayers, id: "test-one", in: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)

    try Bookmarks.restore(draft, language: "en", in: context, defaults: defaults)
    let restored = try context.fetch(FetchDescriptor<Bookmark>())
    #expect(restored.map(\.itemId) == ["test-one"])
    #expect(restored.first?.createdAt == created)
    #expect(restored.first?.language == "en")
    #expect(BookmarkRemovals.all(defaults: defaults).isEmpty)
}

@Test func `a different account does not receive the earlier account's bookmarks`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let accountStore = MemorySessionStore()
    accountStore.saveCachedAccount(#"{"profile":{"id":"user_2","email":"bo@example.com","name":"Bo"},"method":"email"}"#)
    BookmarkOwner.set("user_1", defaults: defaults)
    context.insert(Bookmark(type: BookmarkType.prayers, itemId: "test-one", titleSnapshot: "Test prayer one", language: "en", createdAt: .now))
    try context.save()

    let script = ReplyScript()
    script.enqueue(emptyList)
    script.enqueue(emptyList)
    let session = AppSession(token: "token-2", store: accountStore, defaults: defaults)
    try await session.mergeBookmarks(client: AuthClient(transport: script, authBase: base, apiBase: base), context: context)

    let put = try #require(script.requests.first { $0.httpMethod == "PUT" })
    let sent = try JSONDecoder().decode([BookmarkDraft].self, from: put.httpBody ?? Data())
    #expect(sent.isEmpty)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)
    #expect(BookmarkOwner.matches("user_2", defaults: defaults))
    #expect(defaults.string(forKey: BookmarkOwner.storageKey)?.contains("user_2") == false)
}

@Test func `a saved prayer opens in the language the reader has open`() {
    func body(_ code: String) -> DevotionBody {
        .prayers(language: code, prayers: [SpecialPrayer(order: 1, id: "test-one", title: "Prayer \(code)", summary: nil, category: nil, text: "Test")])
    }
    let installed: Set<String> = ["prayers-en", "prayers-la"]
    let load: (DevotionKind, String) -> DevotionBody? = { _, code in body(code) }

    let inLatin = DevotionBookmarks.locate(type: "prayers", id: "test-one", language: "en", current: "la", installed: installed, load: load)
    #expect(inLatin == LocatedDevotion(language: "la", title: "Prayer la"))

    let notInstalled = DevotionBookmarks.locate(type: "prayers", id: "test-one", language: "en", current: "es", installed: installed, load: load)
    #expect(notInstalled?.language == "en")

    let missingThere = DevotionBookmarks.locate(
        type: "prayers", id: "test-one", language: "en", current: "la", installed: installed,
        load: { _, code in code == "la" ? nil : body(code) }
    )
    #expect(missingThere?.language == "en")
}

// MARK: Sign-in

@Test func `a link that opened the app waits for confirmation`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let script = ReplyScript()
    script.enqueue(adaSession)
    let client = AuthClient(transport: script, authBase: base, apiBase: base)
    let session = AppSession(token: nil, store: MemorySessionStore(), defaults: defaults)
    let link = try #require(URL(string: "perfectliturgy://auth?session_token=from-mail"))

    await session.accept(link, client: client, context: context)
    #expect(!session.isSignedIn)
    #expect(session.incoming?.email == "ada@example.com")
    #expect(script.requests.count == 1)

    session.declineIncoming()
    #expect(session.incoming == nil)
    #expect(!session.isSignedIn)

    script.enqueue(adaSession)
    await session.accept(link, client: client, context: context)
    #expect(session.incoming != nil)
    script.enqueue(adaSession)
    script.enqueue(emptyList)
    script.enqueue(emptyList)
    await session.confirmIncoming(client: client, context: context)
    #expect(session.isSignedIn)
    #expect(session.token == "from-mail")
    #expect(session.incoming == nil)
}

@Test func `a link with a bad token does not end the session on this device`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let store = MemorySessionStore()
    try store.save("good")
    let session = AppSession(store: store, defaults: defaults)
    let script = ReplyScript()
    script.enqueue(status: 401)
    let client = AuthClient(transport: script, authBase: base, apiBase: base)
    let link = try #require(URL(string: "perfectliturgy://auth?session_token=forged"))

    await session.accept(link, client: client, context: context)
    #expect(session.token == "good")
    #expect(store.token == "good")
    #expect(session.incoming == nil)
}

@Test func `only a 401 from get-session ends the session`() async throws {
    let forbidden = ReplyScript()
    forbidden.enqueue(status: 403)
    let client = AuthClient(transport: forbidden, authBase: base, apiBase: base)
    await #expect(throws: AuthError.transport) {
        try await client.currentSession(bearer: "token")
    }

    let store = MemorySessionStore()
    try store.save("token")
    let session = AppSession(store: store, defaults: try freshDefaults())
    let blocked = ReplyScript()
    blocked.enqueue(status: 403)
    await session.restore(client: AuthClient(transport: blocked, authBase: base, apiBase: base))
    #expect(session.isSignedIn)
    #expect(store.token == "token")
}

@Test func `a sign-out the server did not hear is sent again on the next launch`() async throws {
    let store = MemorySessionStore()
    try store.save("session-1")
    let session = AppSession(store: store, defaults: try freshDefaults())

    let offline = ReplyScript()
    offline.enqueue(status: 503)
    await session.signOut(client: AuthClient(transport: offline, authBase: base, apiBase: base))
    #expect(!session.isSignedIn)
    #expect(store.pendingRevoke == "session-1")

    let online = ReplyScript()
    online.enqueue(status: 200)
    await session.restore(client: AuthClient(transport: online, authBase: base, apiBase: base))
    #expect(store.pendingRevoke == nil)
    let request = try #require(online.requests.first)
    #expect(request.url?.path == "/api/auth/sign-out")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-1")
}

// MARK: Packs and media

@Test func `a pack id can only name a file inside the pack folder`() async throws {
    #expect(PackID.isValid("hymns-en"))
    #expect(PackID.isValid("readings-kjv_2"))
    #expect(!PackID.isValid("../x"))
    #expect(!PackID.isValid("a/b"))
    #expect(!PackID.isValid(""))
    #expect(!PackID.isValid("x.json"))

    let root = URL(fileURLWithPath: "/tmp/packs", isDirectory: true)
    #expect(PackFiles.file(for: "../escape", root: root).deletingLastPathComponent().path == root.path)

    let script = ReplyScript()
    let client = PackClient(transport: script, apiBase: base, token: "token")
    await #expect(throws: PackHTTPError.status(404)) {
        try await client.download(packId: "../x")
    }
    await #expect(throws: PackHTTPError.status(404)) {
        try await client.sync(packId: "a/b", since: "1")
    }
    #expect(script.requests.isEmpty)

    script.enqueue("""
    {"data":[{"pack_id":"hymns-en","type":"hymns","display_name":"English Hymns","mode":"live"},{"pack_id":"../x","type":"hymns","display_name":"Bad","mode":"live"}],"page":1,"page_size":2,"total":2}
    """)
    let catalog = try await client.catalog()
    #expect(catalog.map(\.packId) == ["hymns-en"])
}

@Test func `media links open only over https and videos match the exact host`() throws {
    #expect(HymnMediaURL.safe("https://example.com/a.mp3") != nil)
    #expect(HymnMediaURL.safe(" https://example.com/a.mp3 ") != nil)
    #expect(HymnMediaURL.safe("http://example.com/a.mp3") == nil)
    #expect(HymnMediaURL.safe("file:///etc/hosts") == nil)
    #expect(HymnMediaURL.safe("tel:123") == nil)
    #expect(HymnMediaURL.safe("javascript:alert(1)") == nil)

    let fake = try #require(URL(string: "https://notyoutube.com/watch?v=abcdefghijk"))
    #expect(HymnVideo.embedURL(for: fake) == nil)
    let tricky = try #require(URL(string: "https://youtube.com.evil.test/watch?v=abcdefghijk"))
    #expect(HymnVideo.embedURL(for: tricky) == nil)
    let real = try #require(URL(string: "https://m.youtube.com/watch?v=abcdefghijk"))
    #expect(HymnVideo.embedURL(for: real)?.absoluteString == "https://www.youtube.com/embed/abcdefghijk")
    let short = try #require(URL(string: "https://youtu.be/abcdefghijk"))
    #expect(HymnVideo.youtubeID(from: short) == "abcdefghijk")
    let injected = try #require(URL(string: "https://www.youtube.com/watch?v=abc%2F..%2Fx%3Fy%3D1"))
    #expect(HymnVideo.youtubeID(from: injected) == nil)
}


// MARK: Account profile in the Keychain

@Test func `an earlier name and email move from preferences into the store`() throws {
    let defaults = try freshDefaults()
    defaults.set(Data(#"{"id":"user_1","email":"ada@example.com","name":"Ada"}"#.utf8), forKey: "account.profile")
    defaults.set(SignInMethod.google.rawValue, forKey: "account.signInMethod")
    let store = MemorySessionStore()
    let session = AppSession(token: "session-1", store: store, defaults: defaults)
    #expect(session.profile?.email == "ada@example.com")
    #expect(session.method == .google)
    #expect(store.cachedAccount?.contains("ada@example.com") == true)
    #expect(defaults.object(forKey: "account.profile") == nil)
    #expect(defaults.object(forKey: "account.signInMethod") == nil)
}

@Test func `an old name and email are deleted when nobody is signed in`() throws {
    let defaults = try freshDefaults()
    defaults.set(Data(#"{"id":"user_1","email":"ada@example.com","name":"Ada"}"#.utf8), forKey: "account.profile")
    let store = MemorySessionStore()
    let session = AppSession(token: nil, store: store, defaults: defaults)
    #expect(session.profile == nil)
    #expect(store.cachedAccount == nil)
    #expect(defaults.object(forKey: "account.profile") == nil)
}

@Test func `the account cache never writes to preferences`() throws {
    let defaults = try freshDefaults()
    let store = MemorySessionStore()
    AccountCache(store: store, defaults: defaults)
        .save(profile: AccountProfile(id: "user_1", email: "ada@example.com", name: "Ada"), method: .email)
    #expect(defaults.object(forKey: "account.profile") == nil)
    #expect(AccountCache(store: store, defaults: defaults).profile()?.name == "Ada")
    AccountCache(store: store, defaults: defaults).clear()
    #expect(store.cachedAccount == nil)
}

@Test func `the device token memory keeps no account id in plain text`() throws {
    let defaults = try freshDefaults()
    DeviceMemory.remember(token: "t", accountID: "user_1", defaults: defaults)
    #expect(defaults.string(forKey: DeviceMemory.accountKey)?.contains("user_1") == false)
    #expect(DeviceMemory.needsSend(token: "t", accountID: "user_1", defaults: defaults) == false)
    #expect(DeviceMemory.needsSend(token: "t", accountID: "user_2", defaults: defaults))
}

// MARK: Bookmark limit

private func addHymn(_ n: Int, to context: ModelContext, at date: Date) {
    context.insert(Bookmark(type: BookmarkType.hymns, itemId: "h\(n)", titleSnapshot: "Test hymn \(n)", language: "en", createdAt: date))
}

@Test func `the 51st saved item replaces the oldest across hymns and prayers`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    context.insert(Bookmark(type: BookmarkType.prayers, itemId: "test-one", titleSnapshot: "Test prayer one", language: "en", createdAt: start))
    for n in 1...49 { addHymn(n, to: context, at: start.addingTimeInterval(Double(n))) }
    try context.save()
    #expect(try BookmarkLimit.enforce(in: context, defaults: defaults) == 0)

    try Bookmarks.toggle(type: BookmarkType.litanies, id: "test-two", title: "Test litany two", language: "en", in: context, defaults: defaults)
    let all = try context.fetch(FetchDescriptor<Bookmark>())
    #expect(all.count == 50)
    #expect(!all.contains { $0.itemId == "test-one" })
    #expect(all.contains { $0.itemId == "test-two" })
    #expect(all.filter { $0.type == BookmarkType.hymns }.count == 49)
    #expect(BookmarkRemovals.all(defaults: defaults)["prayers|test-one"] != nil)
}

@Test func `a saved hymn past fifty drops the oldest hymn`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    for n in 1...50 { addHymn(n, to: context, at: start.addingTimeInterval(Double(n))) }
    try context.save()
    let record = try insertHymn(id: "h51", language: "en", title: "Test hymn 51", massParts: [], in: context)
    try toggleHymnBookmark(record, in: context, defaults: defaults)
    let ids = Set(try context.fetch(FetchDescriptor<Bookmark>()).map(\.itemId))
    #expect(ids.count == 50)
    #expect(!ids.contains("h1"))
    #expect(ids.contains("h51"))
}

@Test func `an item dropped by the limit does not come back from the account`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    for n in 1...50 { addHymn(n, to: context, at: start.addingTimeInterval(Double(n * 1000))) }
    try context.save()
    let old = BookmarkDraft(type: BookmarkType.hymns, id: "old", titleSnapshot: "Test hymn old", createdAt: BookmarkSync.milliseconds(start.addingTimeInterval(-5000)))

    try BookmarkSync.merge([old], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).count == 50)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).allSatisfy { $0.itemId != "old" })

    try BookmarkSync.merge([old], into: context, defaults: defaults)
    #expect(try context.fetch(FetchDescriptor<Bookmark>()).allSatisfy { $0.itemId != "old" })
}

@Test func `a new device with many account rows keeps the newest fifty`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    defer { withExtendedLifetime(container) {} }
    let defaults = try freshDefaults()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let rows = (1...60).map {
        BookmarkDraft(type: BookmarkType.hymns, id: "h\($0)", titleSnapshot: "Test hymn \($0)", createdAt: BookmarkSync.milliseconds(start.addingTimeInterval(Double($0 * 1000))))
    }
    try BookmarkSync.merge(rows, into: context, defaults: defaults)
    let ids = Set(try context.fetch(FetchDescriptor<Bookmark>()).map(\.itemId))
    #expect(ids.count == 50)
    #expect(ids.contains("h60") && ids.contains("h11"))
    #expect(!ids.contains("h10") && !ids.contains("h1"))
}
