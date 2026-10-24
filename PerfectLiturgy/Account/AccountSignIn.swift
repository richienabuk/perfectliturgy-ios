import AuthenticationServices
import CryptoKit
import Security
import UIKit

enum InterfaceAnchor {
    @MainActor
    static var window: ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        if let key = windows.first(where: \.isKeyWindow) { return key }
        if let any = windows.first { return any }
        return ASPresentationAnchor()
    }
}

enum AppleNonce {
    static func make(count: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "A nonce needs random bytes.")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct AppleCredential: Equatable, Sendable {
    var identityToken: String
    var nonce: String
    var name: String?
}

/// Google and the magic-link return use the system browser, then `perfectliturgy://auth`.
final class WebSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var resumed = false

    func authenticate(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "perfectliturgy"
            ) { callback, error in
                Task { @MainActor in
                    if let callback {
                        self.finish(.success(callback))
                    } else {
                        self.finish(.failure(Self.map(error)))
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                finish(.failure(AuthError.transport))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { InterfaceAnchor.window }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !resumed else { return }
        resumed = true
        session = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }

    private static func map(_ error: Error?) -> Error {
        guard let error else { return AuthError.transport }
        let nsError = error as NSError
        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
            return AuthError.cancelled
        }
        return AuthError.transport
    }
}

/// The system Apple sheet. The server must accept the identity token before a session is stored.
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var controller: ASAuthorizationController?
    private var continuation: CheckedContinuation<AppleCredential, Error>?
    private var nonce = ""
    private var resumed = false

    func authenticate() async throws -> AppleCredential {
        let nonce = AppleNonce.make()
        self.nonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { InterfaceAnchor.window }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        MainActor.assumeIsolated {
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let data = credential.identityToken,
                let token = String(data: data, encoding: .utf8),
                !token.isEmpty
            else {
                finish(.failure(AuthError.appleUnavailable))
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            finish(.success(AppleCredential(
                identityToken: token,
                nonce: nonce,
                name: name.isEmpty ? nil : name
            )))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                finish(.failure(AuthError.cancelled))
            } else {
                finish(.failure(AuthError.appleUnavailable))
            }
        }
    }

    private func finish(_ result: Result<AppleCredential, Error>) {
        guard !resumed else { return }
        resumed = true
        controller = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}
