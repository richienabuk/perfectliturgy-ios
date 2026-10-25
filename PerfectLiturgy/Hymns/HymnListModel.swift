import Observation
import os
import SwiftData

/// Holds the hymn catalogue and the list derived from it.
///
/// The derived values are stored. They change only when `refilter` runs, so a screen
/// can read them in `body` as often as it likes without filtering the catalogue again.
@Observable @MainActor
final class HymnListModel {
    struct Inputs: Equatable {
        var installed: Set<String> = []
        var language: String?
        var season: String?
        var massPart: String?
        var query: String = ""
        /// Hymn catalogues from the pack list. They name the language on each row.
        var catalogues: [PackRecord] = []
    }

    /// What one list row shows. Built once per refilter, not once per body pass.
    nonisolated struct Row: Equatable, Identifiable, Sendable {
        var id: String
        var hymnNumber: Int
        var title: String
        var line: String
    }

    private(set) var catalogue: [HymnSummary] = []
    /// Installed languages that have at least one hymn, English and Latin first.
    private(set) var languages: [String] = []
    /// The chosen language while it is still on the device. Nil shows every catalogue.
    private(set) var activeLanguage: String?
    private(set) var filtered: [HymnSummary] = []
    private(set) var rows: [Row] = []

    /// False until the first read finishes. The list shows nothing, not "No hymns match", until then.
    private(set) var isLoaded = false

    private var inputs = Inputs()
    private var loadGeneration = 0

    /// Reads the catalogue off the main thread. A later load wins over an earlier one that finishes after it.
    func load(from container: ModelContainer, inputs: @MainActor () -> Inputs) async {
        loadGeneration += 1
        let mine = loadGeneration
        let summaries = await HymnCatalogueReader.load(from: container)
        guard mine == loadGeneration else { return }
        setCatalogue(summaries, inputs: inputs())
    }

    func setCatalogue(_ catalogue: [HymnSummary], inputs: Inputs) {
        self.catalogue = catalogue
        isLoaded = true
        refilter(inputs, force: true)
    }

    func refilter(_ inputs: Inputs, force: Bool = false) {
        guard force || inputs != self.inputs else { return }
        let signpost = Performance.signposter.beginInterval("hymns.refilter")
        defer { Performance.signposter.endInterval("hymns.refilter", signpost) }
        let catalogueNamesChanged = inputs.catalogues != self.inputs.catalogues
        self.inputs = inputs

        let installed = inputs.installed
        let languages = HymnLanguage.ordered(catalogue.map(\.language).filter { installed.contains($0) })
        let active = inputs.language.flatMap { languages.contains($0) ? $0 : nil }
        let filter = HymnFilter(
            text: inputs.query,
            language: active,
            season: inputs.season,
            massPart: inputs.massPart
        )
        let query = HymnQuery(inputs.query)
        let matches = catalogue.filter {
            installed.contains($0.language) && HymnSearch.matches($0, filter: filter, query: query)
        }

        // Assign only what changed, so views that read one value are not invalidated by the others.
        if self.languages != languages { self.languages = languages }
        if activeLanguage != active { activeLanguage = active }
        let listChanged = filtered != matches
        if listChanged { filtered = matches }
        if listChanged || catalogueNamesChanged || force {
            rows = matches.map { hymn in
                Row(
                    id: hymn.id,
                    hymnNumber: hymn.hymnNumber,
                    title: hymn.title,
                    line: HymnLabels.rowLine(
                        language: hymn.language,
                        seasons: hymn.seasons,
                        massParts: hymn.massParts,
                        catalogues: inputs.catalogues
                    )
                )
            }
        }
    }
}
