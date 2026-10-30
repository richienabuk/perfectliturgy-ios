import Foundation
import Security
import SwiftData

/// Words on the Account screen. Short sentences, from the product spec.
enum AccountCopy {
    static let signedOutTitle = "Use an Account"
    static let signedOutSupport = "Sign in to download language packs and sync your saved items across devices."
    static let signedInTitle = "Your Account"
    static let savedTitle = "Saved items"
    static let syncTitle = "Sync status"
    static let syncStatus = "Update hymns and readings."
    static let magicLinkSent = "Check your email for a sign-in link."
    static let appleUnavailable = "Sign in with Apple is not available yet."
    static let signInFailed = "Sign-in did not finish. Try again."
    static let connection = "Check the connection and try again."
    static let emailMissing = "Enter an email address."
    static let bookmarksKept = "Saved items stay on this device. They will join your Account when you're online."
    static let confirmTitle = "Sign in?"
    static let confirmAction = "Sign in"

    static func confirmMessage(email: String, replacing current: String?) -> String {
        if let current, !current.isEmpty, current != email {
            return "A link wants to sign in \(email). You are signed in as \(current). Only continue if you asked for this link."
        }
        return "A link wants to sign in \(email). Only continue if you asked for this link."
    }

    static func savedDetail(count: Int) -> String {
        switch count {
        case 0: "Nothing saved on this device."
        case 1: "1 item · stored on this device."
        default: "\(count) items · stored on this device."
        }
    }

    static func methodLine(_ method: SignInMethod) -> String {
        switch method {
        case .google: "Signed in with Google"
        case .apple: "Signed in with Apple"
        case .email: "Signed in with email"
        }
    }
}

enum SignInMethod: String, Codable, Equatable, Sendable {
    case google
    case apple
    case email
}

struct AccountProfile: Codable, Equatable, Sendable {
    var id: String
    var email: String
    var name: String
}

protocol SessionStoring: AnyObject {
    var token: String? { get }
    func save(_ token: String) throws
    func clear()
    /// A token the server has not yet been told to end. It is tried again on the next launch.
    var pendingRevoke: String? { get }
    func savePendingRevoke(_ token: String)
    func clearPendingRevoke()
    /// The signed-in name and email, kept so the Account screen can show them before the server answers.
    var cachedAccount: String? { get }
    func saveCachedAccount(_ json: String)
    func clearCachedAccount()
}

enum KeychainSession {
    static let service = "com.perfectliturgy.session"
    static let account = "token"
    static let revokeAccount = "revoke"
    static let profileAccount = "profile"

    static var token: String? {
        read(service: service, account: account)
    }

    static func read(service: String, account: String) -> String? {
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

    static func save(_ token: String, service: String = service, account: String = account) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(add as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
            return
        }
        guard updated == errSecSuccess else { throw KeychainError(status: updated) }
    }

    static func clear(service: String = service, account: String = account) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct KeychainError: Error, Equatable {
    var status: OSStatus
}

final class KeychainSessionStore: SessionStoring {
    var service: String
    var account: String

    init(service: String = KeychainSession.service, account: String = KeychainSession.account) {
        self.service = service
        self.account = account
    }

    var token: String? {
        KeychainSession.read(service: service, account: account)
    }

    func save(_ token: String) throws {
        try KeychainSession.save(token, service: service, account: account)
    }

    func clear() {
        KeychainSession.clear(service: service, account: account)
    }

    var pendingRevoke: String? {
        KeychainSession.read(service: service, account: KeychainSession.revokeAccount)
    }

    func savePendingRevoke(_ token: String) {
        try? KeychainSession.save(token, service: service, account: KeychainSession.revokeAccount)
    }

    func clearPendingRevoke() {
        KeychainSession.clear(service: service, account: KeychainSession.revokeAccount)
    }

    var cachedAccount: String? {
        KeychainSession.read(service: service, account: KeychainSession.profileAccount)
    }

    func saveCachedAccount(_ json: String) {
        try? KeychainSession.save(json, service: service, account: KeychainSession.profileAccount)
    }

    func clearCachedAccount() {
        KeychainSession.clear(service: service, account: KeychainSession.profileAccount)
    }
}

final class MemorySessionStore: SessionStoring {
    var token: String?

    func save(_ token: String) throws {
        self.token = token
    }

    func clear() {
        token = nil
    }

    var pendingRevoke: String?

    func savePendingRevoke(_ token: String) {
        pendingRevoke = token
    }

    func clearPendingRevoke() {
        pendingRevoke = nil
    }

    var cachedAccount: String?

    func saveCachedAccount(_ json: String) {
        cachedAccount = json
    }

    func clearCachedAccount() {
        cachedAccount = nil
    }
}

/// The signed-in name and email. They live in the Keychain with the session, never in UserDefaults.
struct AccountCache {
    var store: any SessionStoring
    /// Read only to move what an earlier version saved there, then emptied.
    var defaults: UserDefaults

    private let legacyProfileKey = "account.profile"
    private let legacyMethodKey = "account.signInMethod"

    private struct Stored: Codable {
        var profile: AccountProfile
        var method: SignInMethod
    }

    private var stored: Stored? {
        guard let json = store.cachedAccount else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: Data(json.utf8))
    }

    func profile() -> AccountProfile? { stored?.profile }

    func method() -> SignInMethod? { stored?.method }

    func save(profile: AccountProfile, method: SignInMethod) {
        guard let data = try? JSONEncoder().encode(Stored(profile: profile, method: method)),
              let json = String(data: data, encoding: .utf8)
        else { return }
        store.saveCachedAccount(json)
    }

    func clear() {
        store.clearCachedAccount()
        removeLegacy()
    }

    /// Moves a name and email left in UserDefaults by an earlier version into the Keychain.
    /// The old keys are removed whether or not a session is there to use them.
    func migrateLegacy(hasSession: Bool) {
        defer { removeLegacy() }
        guard hasSession, store.cachedAccount == nil,
              let data = defaults.data(forKey: legacyProfileKey),
              let profile = try? JSONDecoder().decode(AccountProfile.self, from: data)
        else { return }
        let method = defaults.string(forKey: legacyMethodKey).flatMap(SignInMethod.init(rawValue:)) ?? .email
        save(profile: profile, method: method)
    }

    private func removeLegacy() {
        defaults.removeObject(forKey: legacyProfileKey)
        defaults.removeObject(forKey: legacyMethodKey)
    }
}

struct IncomingSignIn: Equatable, Identifiable {
    var session: ConfirmedSession
    var method: SignInMethod
    var email: String

    var id: String { session.token }
}

/// The signed-in session. The token lives in the Keychain. Hymns, bookmarks, and packs stay on sign-out.
@Observable
final class AppSession {
    private(set) var token: String?
    private(set) var profile: AccountProfile?
    private(set) var method: SignInMethod?
    var notice: String?
    var isWorking = false
    /// A sign-in link that opened the app from outside. It waits for the reader to confirm.
    var incoming: IncomingSignIn?

    private let store: any SessionStoring
    private let cache: AccountCache
    private let defaults: UserDefaults
    private var pendingMethod: SignInMethod?
    private var activeToken: String?
    private var isMerging = false
    private var mergeAgain = false

    var isSignedIn: Bool {
        guard let token else { return false }
        return !token.isEmpty
    }

    init(store: any SessionStoring = KeychainSessionStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        self.cache = AccountCache(store: store, defaults: defaults)
        let stored = store.token
        self.token = stored
        cache.migrateLegacy(hasSession: stored?.isEmpty == false)
        if let stored, !stored.isEmpty {
            profile = cache.profile()
            method = cache.method()
        }
    }

    init(token: String?, store: any SessionStoring = KeychainSessionStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        self.cache = AccountCache(store: store, defaults: defaults)
        self.token = token
        cache.migrateLegacy(hasSession: token?.isEmpty == false)
        if let token, !token.isEmpty {
            profile = cache.profile()
            method = cache.method()
        }
    }

    func prepare(_ method: SignInMethod) {
        pendingMethod = method
        notice = nil
    }

    /// Keeps the PKCE verifier until the browser or magic-link return finishes.
    func remember(_ pkce: AuthPKCE) {
        AuthPKCEStore.save(pkce, defaults: defaults)
    }

    func cancelPending() {
        pendingMethod = nil
        isWorking = false
        AuthPKCEStore.clear(defaults: defaults)
    }

    /// Confirm a stored token on launch. A rejected session signs out. A network failure keeps the token.
    func restore(client: AuthClient) async {
        await finishPendingSignOut(client: client)
        guard let token, !token.isEmpty else { return }
        do {
            let confirmed = try await client.currentSession(bearer: token)
            try apply(confirmed, method: method ?? .email)
        } catch AuthError.rejected {
            signOutLocal()
        } catch {
            return
        }
    }

    /// `trusted` is true only for the callback of the browser session this app started.
    /// A link that opened the app from outside, such as the emailed one, could come from anywhere.
    /// It waits for the reader to confirm which Account it signs in, and changes nothing until then.
    func accept(_ url: URL, client: AuthClient, context: ModelContext, trusted: Bool = false) async {
        guard AuthReturn.accepts(url) else {
            isWorking = false
            return
        }
        switch AuthReturn.callback(from: url) {
        case .code(let code, let state):
            await redeem(code: code, state: state, client: client, context: context, trusted: trusted)
        case .session(let token):
            if trusted {
                await establish(
                    token: token,
                    method: pendingMethod ?? .email,
                    client: client,
                    context: context
                )
            } else {
                await review(token: token, client: client)
            }
        case .failure:
            isWorking = false
            notice = AccountCopy.signInFailed
            AuthPKCEStore.clear(defaults: defaults)
        case nil:
            isWorking = false
        }
    }

    /// Exchanges the one-time bridge code, then confirms or stores the Account.
    private func redeem(
        code: String,
        state: String,
        client: AuthClient,
        context: ModelContext,
        trusted: Bool
    ) async {
        guard let pkce = AuthPKCEStore.load(defaults: defaults), pkce.state == state else {
            isWorking = false
            notice = AccountCopy.signInFailed
            AuthPKCEStore.clear(defaults: defaults)
            return
        }
        isWorking = true
        do {
            let token = try await client.exchangeMobileCode(
                code: code,
                state: state,
                verifier: pkce.verifier
            )
            AuthPKCEStore.clear(defaults: defaults)
            if trusted {
                await establish(
                    token: token,
                    method: pendingMethod ?? .email,
                    client: client,
                    context: context
                )
            } else {
                await review(token: token, client: client)
            }
        } catch AuthError.rejected {
            isWorking = false
            notice = AccountCopy.signInFailed
            AuthPKCEStore.clear(defaults: defaults)
        } catch {
            isWorking = false
            notice = AccountCopy.connection
        }
    }

    /// Looks up the Account a link would sign in. The session on this device stays as it is.
    private func review(token: String, client: AuthClient) async {
        if token == self.token {
            isWorking = false
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let confirmed = try await client.currentSession(bearer: token)
            if confirmed.profile.id == profile?.id, isSignedIn { return }
            incoming = IncomingSignIn(
                session: confirmed,
                method: pendingMethod ?? .email,
                email: confirmed.profile.email
            )
        } catch AuthError.rejected {
            notice = AccountCopy.signInFailed
        } catch {
            notice = AccountCopy.connection
        }
    }

    func confirmIncoming(client: AuthClient, context: ModelContext) async {
        guard let waiting = incoming else { return }
        incoming = nil
        await establish(token: waiting.session.token, method: waiting.method, client: client, context: context)
    }

    func declineIncoming() {
        incoming = nil
        isWorking = false
    }

    func sendMagicLink(email: String, client: AuthClient) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AccountEmail.isValid(trimmed) else {
            notice = AccountCopy.emailMissing
            return
        }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            let pkce = AuthPKCE.make()
            remember(pkce)
            try await client.sendMagicLink(email: trimmed, pkce: pkce)
            pendingMethod = .email
            notice = AccountCopy.magicLinkSent
        } catch {
            AuthPKCEStore.clear(defaults: defaults)
            notice = AccountCopy.connection
        }
    }

    func signInWithApple(
        identityToken: String,
        nonce: String,
        name: String?,
        client: AuthClient,
        context: ModelContext
    ) async {
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            let token = try await client.exchangeApple(identityToken: identityToken, nonce: nonce)
            await establish(token: token, method: .apple, name: name, client: client, context: context)
        } catch AuthError.appleUnavailable {
            notice = AccountCopy.appleUnavailable
        } catch AuthError.cancelled {
            return
        } catch {
            notice = AccountCopy.connection
        }
    }

    func signOut(client: AuthClient) async {
        let current = token
        signOutLocal()
        guard let current, !current.isEmpty else { return }
        store.savePendingRevoke(current)
        if await client.signOut(bearer: current) {
            store.clearPendingRevoke()
        }
    }

    /// A sign-out that could not reach the server is sent again, so the old session does not stay valid.
    private func finishPendingSignOut(client: AuthClient) async {
        guard let pending = store.pendingRevoke, !pending.isEmpty else { return }
        if await client.signOut(bearer: pending) {
            store.clearPendingRevoke()
        }
    }

    private func establish(
        token: String,
        method: SignInMethod,
        name: String? = nil,
        client: AuthClient,
        context: ModelContext
    ) async {
        guard activeToken != token else { return }
        activeToken = token
        defer { activeToken = nil }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            let confirmed = try await client.currentSession(bearer: token)
            var profile = confirmed.profile
            if profile.name.isEmpty, let name, !name.isEmpty {
                profile.name = name
            }
            try apply(ConfirmedSession(token: confirmed.token, profile: profile), method: method)
            pendingMethod = nil
            do {
                try await mergeBookmarks(client: client, context: context)
            } catch {
                notice = AccountCopy.bookmarksKept
            }
        } catch AuthError.rejected {
            // The new token was never stored, so a session already on this device stays.
            notice = AccountCopy.signInFailed
        } catch {
            notice = AccountCopy.connection
        }
    }

    private func apply(_ session: ConfirmedSession, method: SignInMethod) throws {
        try store.save(session.token)
        token = session.token
        profile = session.profile
        self.method = method
        cache.save(profile: session.profile, method: method)
    }

    /// Pushes this device's bookmarks, then reads the account's. One merge runs at a time.
    /// A change that arrives while one runs is covered by one more pass.
    func mergeBookmarks(client: AuthClient, context: ModelContext) async throws {
        guard let token, !token.isEmpty else { return }
        if isMerging {
            mergeAgain = true
            return
        }
        isMerging = true
        defer { isMerging = false }
        repeat {
            mergeAgain = false
            try claimBookmarks(in: context)
            try BookmarkLimit.enforce(in: context, defaults: defaults)
            let pushed = try await client.pushBookmarks(
                BookmarkSync.payload(try context.fetch(FetchDescriptor<Bookmark>()), defaults: defaults),
                bearer: token
            )
            try BookmarkSync.merge(pushed, into: context, defaults: defaults)
            let remote = try await client.bookmarks(bearer: token)
            try BookmarkSync.merge(remote, into: context, defaults: defaults)
        } while mergeAgain
    }

    /// Saved items belong to one Account. When a different Account signs in on this device, the
    /// earlier Account's items are cleared first, so they are never sent to the new one.
    /// Items saved while signed out, before the first sign-in, join the Account that signs in.
    private func claimBookmarks(in context: ModelContext) throws {
        guard let id = profile?.id, !id.isEmpty else { return }
        if BookmarkOwner.isOtherAccount(id, defaults: defaults) {
            for bookmark in try context.fetch(FetchDescriptor<Bookmark>()) {
                context.delete(bookmark)
            }
            try context.save()
            BookmarkRemovals.reset(defaults: defaults)
        }
        BookmarkOwner.set(id, defaults: defaults)
    }

    private func signOutLocal() {
        store.clear()
        token = nil
        profile = nil
        method = nil
        pendingMethod = nil
        notice = nil
        cache.clear()
    }
}

enum AccountEmail {
    static func isValid(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !domain.contains("@")
    }
}
