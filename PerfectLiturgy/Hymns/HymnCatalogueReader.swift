import Foundation
import SwiftData

/// Reads the hymn list on its own context, off the main thread.
///
/// It returns plain copies, so a screen never holds a row that a pack removal deletes.
/// It loads only the columns a list row needs. It does not touch lyrics or sections.
@ModelActor
actor HymnCatalogueReader {
    func summaries() -> [HymnSummary] {
        var descriptor = FetchDescriptor<HymnRecord>(sortBy: [
            SortDescriptor(\.language),
            SortDescriptor(\.hymnNumber),
        ])
        descriptor.propertiesToFetch = [
            \.id, \.language, \.hymnNumber, \.title, \.firstLine, \.searchKey,
            \.seasons, \.massParts, \.topics,
        ]
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(\.summary)
    }

    /// Creates the reader away from the main actor, so its context does not run on the main thread.
    static func load(from container: ModelContainer) async -> [HymnSummary] {
        await Task.detached(priority: .userInitiated) {
            await HymnCatalogueReader(modelContainer: container).summaries()
        }.value
    }
}
