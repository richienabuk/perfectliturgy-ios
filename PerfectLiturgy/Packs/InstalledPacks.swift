import Foundation

/// Pack ids that ship in the app. Readings and country calendars are not among them.
enum ContentPack {
    static let bundledIDs = [
        "hymns-en",
        "hymns-la",
        "order-en",
        "order-la",
        "rosary-en",
        "rosary-la",
        "stations-en",
        "stations-la",
        "prayers-en",
        "prayers-la",
    ]

    static func hymnID(for language: String) -> String {
        "hymns-\(language)"
    }
}

/// Installed pack ids. A missing key means the bundled set. Removal writes the list that remains.
@Observable
final class InstalledPacks {
    static let storageKey = "installedPackIDs"

    private let defaults: UserDefaults
    private(set) var ids: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.stringArray(forKey: Self.storageKey) {
            ids = Set(stored)
        } else {
            ids = Set(ContentPack.bundledIDs)
        }
    }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func remove(_ id: String) {
        guard ids.contains(id) else { return }
        ids.remove(id)
        defaults.set(ids.sorted(), forKey: Self.storageKey)
    }
}
