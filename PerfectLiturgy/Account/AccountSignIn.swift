import AuthenticationServices
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

/// Google and Apple open the system browser, then return on `perfectliturgy://auth`.
@MainActor
final class WebSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var resumed = false
    /// Set on the main actor before `start()`. The system may ask for it off the main actor.
    nonisolated(unsafe) private var anchor: ASPresentationAnchor?

    func authenticate(_ url: URL) async throws -> URL {
        anchor = InterfaceAnchor.window
        return try await withCheckedThrowingContinuation { continuation in
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
        anchor ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !resumed else { return }
        resumed = true
        session = nil
        anchor = nil
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
