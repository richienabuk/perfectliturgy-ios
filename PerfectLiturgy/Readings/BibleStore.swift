import Foundation
import OSLog
import SwiftData

/// The Bible SwiftData store. Separate from hymns and bookmarks so a failed open never drops saved items.
enum BibleStore {
    private static let logger = Logger(subsystem: "com.perfectliturgy", category: "bible")
    private static let folderName = "Bible"
    private static let storeName = "bible"

    static let shared: ModelContainer = open()

    /// Opens the store. A failed open deletes the folder, clears every `readings-` install, and tries again.
    private static func open() -> ModelContainer {
        do {
            return try make(inMemory: false)
        } catch {
            logger.error("The Bible store could not be opened. It is reset.")
            clearFolder()
            clearReadingsInstallState(defaults: .standard)
            if let fresh = try? make(inMemory: false) {
                return fresh
            }
            if let temporary = try? make(inMemory: true) {
                return temporary
            }
            fatalError("The Bible store could not be opened.")
        }
    }

    static func make(inMemory: Bool) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(
                "\(storeName)-\(UUID().uuidString)",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(for: schema, configurations: configuration)
        }
        let folder = try storeFolder()
        let url = folder.appending(path: "\(storeName).store")
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// A file-backed store at a chosen URL, for tests.
    static func make(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Removes every installed `readings-` pack whose version has no verses, and any revision with no verses.
    static func reconcileInstalled(packs: InstalledPacks, defaults: UserDefaults, container: ModelContainer = shared) {
        let context = ModelContext(container)
        let readings = packs.ids.filter { $0.hasPrefix("readings-") }
        for packId in readings {
            let versionID = String(packId.dropFirst("readings-".count))
            if versionID.isEmpty || verseCount(versionID: versionID, in: context) == 0 {
                packs.remove(packId)
                PackFiles.clearRevision(for: packId, defaults: defaults)
            }
        }
    }

    /// Forced open failure path used by tests: wipe the store folder and clear readings install state.
    static func resetForcingClear(defaults: UserDefaults) {
        clearFolder()
        clearReadingsInstallState(defaults: defaults)
    }

    static func verses(
        versionID: String,
        bookID: String,
        fromChapter: Int,
        fromVerse: Int,
        toChapter: Int,
        toVerse: Int,
        in context: ModelContext
    ) throws -> [StoredVerse] {
        let fromPos = BibleVerse.pos(chapter: fromChapter, verse: fromVerse)
        let toPos = BibleVerse.pos(chapter: toChapter, verse: toVerse)
        let predicate = #Predicate<BibleVerse> {
            $0.versionID == versionID && $0.bookID == bookID && $0.pos >= fromPos && $0.pos <= toPos
        }
        var descriptor = FetchDescriptor<BibleVerse>(predicate: predicate, sortBy: [SortDescriptor(\.pos)])
        descriptor.includePendingChanges = true
        let rows = try context.fetch(descriptor)
        return rows.map {
            StoredVerse(chapter: $0.chapter, verse: $0.verse, text: $0.text, segmentsJSON: $0.segmentsJSON)
        }
    }

    static func verseCount(versionID: String, in context: ModelContext) -> Int {
        let predicate = #Predicate<BibleVerse> { $0.versionID == versionID }
        return (try? context.fetchCount(FetchDescriptor<BibleVerse>(predicate: predicate))) ?? 0
    }

    static var schema: Schema {
        Schema([BibleVersion.self, BibleBook.self, BibleVerse.self])
    }

    private static func storeFolder() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = support.appending(path: folderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = folder
        try? mutable.setResourceValues(values)
        return folder
    }

    private static func clearFolder() {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let folder = support.appending(path: folderName, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
    }

    static func clearReadingsInstallState(defaults: UserDefaults) {
        if var stored = defaults.stringArray(forKey: InstalledPacks.storageKey) {
            stored.removeAll { $0.hasPrefix("readings-") }
            defaults.set(stored, forKey: InstalledPacks.storageKey)
        }
        PackFiles.clearAllReadingsRevisions(defaults: defaults)
    }
}
