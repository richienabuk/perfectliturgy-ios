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
    static let syncStatus = "Ready to sync when connected."
    static let magicLinkSent = "Check your email for a sign-in link."
    static let appleUnavailable = "Sign in with Apple is not available yet."
    static let signInFailed = "Sign-in did not finish. Try again."
    static let connection = "Check the connection and try again."
    static let emailMissing = "Enter an email address."
    static let bookmarksKept = "Saved hymns stay on this device. They will join your Account when you're online."

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
}

enum KeychainSession {
    static let service = "com.perfectliturgy.session"
    static let account = "token"

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
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
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
}

final class MemorySessionStore: SessionStoring {
    var token: String?

    func save(_ token: String) throws {
        self.token = token
    }

    func clear() {
        token = nil
    }
}

struct AccountCache {
    var defaults: UserDefaults

    private let profileKey = "account.profile"
    private let methodKey = "account.signInMethod"

    func profile() -> AccountProfile? {
        guard let data = defaults.data(forKey: profileKey) else { return nil }
        return try? JSONDecoder().decode(AccountProfile.self, from: data)
    }

    func method() -> SignInMethod? {
        guard let raw = defaults.string(forKey: methodKey) else { return nil }
        return SignInMethod(rawValue: raw)
    }

    func save(profile: AccountProfile, method: SignInMethod) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: profileKey)
        }
        defaults.set(method.rawValue, forKey: methodKey)
    }

    func clear() {
        defaults.removeObject(forKey: profileKey)
        defaults.removeObject(forKey: methodKey)
    }
}

/// The signed-in session. The token lives in the Keychain. Hymns, bookmarks, and packs stay on sign-out.
@Observable
final class AppSession {
    private(set) var token: String?
    private(set) var profile: AccountProfile?
    private(set) var method: SignInMethod?
    var notice: String?
    var isWorking = false

    private let store: any SessionStoring
    private let cache: AccountCache
    private var pendingMethod: SignInMethod?
    private var activeToken: String?

    var isSignedIn: Bool {
        guard let token else { return false }
        return !token.isEmpty
    }

    init(store: any SessionStoring = KeychainSessionStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.cache = AccountCache(defaults: defaults)
        let stored = store.token
        self.token = stored
        if let stored, !stored.isEmpty {
            profile = cache.profile()
            method = cache.method()
        }
    }

    init(token: String?, store: any SessionStoring = KeychainSessionStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.cache = AccountCache(defaults: defaults)
        self.token = token
        if let token, !token.isEmpty {
            profile = cache.profile()
            method = cache.method()
        }
    }

    func prepare(_ method: SignInMethod) {
        pendingMethod = method
        notice = nil
    }

    func cancelPending() {
        pendingMethod = nil
        isWorking = false
    }

    /// Confirm a stored token on launch. A rejected session signs out. A network failure keeps the token.
    func restore(client: AuthClient) async {
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

    func accept(_ url: URL, client: AuthClient, context: ModelContext) async {
        guard AuthReturn.accepts(url) else {
            isWorking = false
            return
        }
        switch AuthReturn.callback(from: url) {
        case .session(let token):
            await establish(
                token: token,
                method: pendingMethod ?? .email,
                client: client,
                context: context
            )
        case .failure:
            isWorking = false
            notice = AccountCopy.signInFailed
        case nil:
            isWorking = false
        }
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
            try await client.sendMagicLink(email: trimmed)
            pendingMethod = .email
            notice = AccountCopy.magicLinkSent
        } catch {
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
        await client.signOut(bearer: current)
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
                try await syncBookmarks(client: client, context: context)
            } catch {
                notice = AccountCopy.bookmarksKept
            }
        } catch AuthError.rejected {
            signOutLocal()
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

    private func syncBookmarks(client: AuthClient, context: ModelContext) async throws {
        guard let token, !token.isEmpty else { return }
        let local = try context.fetch(FetchDescriptor<HymnBookmark>())
        let pushed = try await client.pushBookmarks(BookmarkSync.payload(from: local), bearer: token)
        try BookmarkSync.merge(pushed, into: context)
        let remote = try await client.bookmarks(bearer: token)
        try BookmarkSync.merge(remote, into: context)
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
