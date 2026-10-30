import Foundation

/// Loads the active lectionary and Bible versions for Readings and Today.
enum LectionarySession {
    /// Legacy preference value for the removed "Lectionary text" menu option.
    private static let legacyLectionaryTextID = "lectionary"

    static func lectionary(
        calendarID: String,
        packs: InstalledPacks,
        root: URL = DevotionLibrary.applicationSupport,
        bundle: Bundle = .main
    ) async -> Lectionary {
        if calendarID == CalendarOption.latinRite.id || calendarID == "roman" {
            return await LectionaryStore.shared.seed(bundle: bundle)
        }
        let file = PackFiles.file(for: calendarID, root: root)
        guard let data = try? Data(contentsOf: file) else {
            return await LectionaryStore.shared.seed(bundle: bundle)
        }
        let revision = PackFiles.revision(for: calendarID, defaults: .standard) ?? ""
        if let loaded = try? await LectionaryStore.shared.lectionary(id: calendarID, revision: revision, data: data) {
            return loaded
        }
        if let decoded = try? CalendarPackReader.decode(data) {
            return decoded
        }
        return await LectionaryStore.shared.seed(bundle: bundle)
    }

    static func bibleVersions() async -> [BibleVersionChoice] {
        let reader = BibleReader(modelContainer: BibleStore.shared)
        return (try? await reader.versions()) ?? []
    }

    static func textSource(
        selection: String?,
        versions: [BibleVersionChoice]
    ) -> (source: TextSource, bible: BibleChoice?) {
        let preferred = selection == legacyLectionaryTextID ? nil : selection
        if let preferred, let match = versions.first(where: { $0.id == preferred }) {
            return (.bible(versionID: match.id), BibleChoice(id: match.id, language: match.language))
        }
        if let first = versions.first {
            return (.bible(versionID: first.id), BibleChoice(id: first.id, language: first.language))
        }
        return (.bible(versionID: ""), nil)
    }
}
