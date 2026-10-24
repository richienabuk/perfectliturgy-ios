import Foundation

/// Accepts `perfectliturgy://auth`. The session is read in a later phase.
nonisolated enum AuthReturn {
    static func accepts(_ url: URL) -> Bool {
        url.scheme == "perfectliturgy"
    }

    static func handle(_ url: URL) {
        guard accepts(url) else { return }
    }
}
