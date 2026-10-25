import Foundation
import Observation

/// The pack list from the saved catalog, read once and kept.
///
/// Every language name on screen comes from here. Screens read `packs` in `body`. Nothing reads
/// `catalog.json` on a tab change or a push. The file is read off the main thread, again only when
/// the pack list is saved.
@Observable @MainActor
final class PackCatalogStore {
    static let shared = PackCatalogStore()

    /// The seeded rows stand in until the first read finishes.
    private(set) var packs: [PackRecord]

    @ObservationIgnored private let root: URL
    @ObservationIgnored private var started = 0
    @ObservationIgnored private var applied = 0

    init(root: URL? = nil) {
        self.root = root ?? DevotionLibrary.applicationSupport
        packs = PackSeed.rows
        // The token is not kept. The closure holds `self` weakly and does nothing once it is gone.
        _ = NotificationCenter.default.addObserver(forName: .packCatalogDidChange, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }
        Task { await reload() }
    }

    /// The rows of one pack type, such as `hymns`.
    func packs(ofType type: String) -> [PackRecord] {
        packs.filter { $0.type == type }
    }

    /// Reads the saved list. When two reads overlap, the one that started last wins,
    /// so a slow read never replaces a newer one. A caller always sees its own read applied
    /// unless a newer read has already been.
    func reload() async {
        started += 1
        let mine = started
        let root = root
        let rows = await Task.detached(priority: .userInitiated) { PackFiles.rowsWithSeeds(root: root) }.value
        guard mine > applied else { return }
        applied = mine
        if rows != packs { packs = rows }
    }
}
