import Foundation
import Observation

/// The hymn catalogues from the saved pack list, read once and kept.
///
/// Screens read `packs` in `body`. Nothing reads `catalog.json` on a tab change or a push.
/// The file is read off the main thread, again only when the pack list is saved.
@Observable @MainActor
final class HymnPackStore {
    static let shared = HymnPackStore()

    /// The seeded English and Latin rows stand in until the first read finishes.
    private(set) var packs: [PackRecord]

    @ObservationIgnored private let root: URL
    @ObservationIgnored private var started = 0
    @ObservationIgnored private var applied = 0

    init(root: URL? = nil) {
        self.root = root ?? DevotionLibrary.applicationSupport
        packs = PackSeed.rows.filter { $0.type == "hymns" }
        // The token is not kept. The closure holds `self` weakly and does nothing once it is gone.
        _ = NotificationCenter.default.addObserver(forName: .packCatalogDidChange, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }
        Task { await reload() }
    }

    /// Reads the saved list. When two reads overlap, the one that started last wins,
    /// so a slow read never replaces a newer one. A caller always sees its own read applied
    /// unless a newer read has already been.
    func reload() async {
        started += 1
        let mine = started
        let root = root
        let rows = await Task.detached(priority: .userInitiated) { PackFiles.hymnRows(root: root) }.value
        guard mine > applied else { return }
        applied = mine
        if rows != packs { packs = rows }
    }
}
