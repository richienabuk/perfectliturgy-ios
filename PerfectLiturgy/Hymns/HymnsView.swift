import SwiftData
import SwiftUI

struct HymnsView: View {
    init(initialQuery: String = "") {
        _query = State(initialValue: initialQuery)
        _debouncedQuery = State(initialValue: initialQuery)
    }

    @Environment(\.palette) private var palette
    @Environment(\.splitsColumns) private var splitsColumns
    @Environment(AppNavigation.self) private var navigation
    @Environment(InstalledPacks.self) private var packs
    @Environment(\.modelContext) private var modelContext

    @State private var model = HymnListModel()
    /// Read once, off the main thread. A pushed screen and a tab change do not read the file again.
    private let packStore = HymnPackStore.shared
    @Query private var bookmarks: [HymnBookmark]

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var language: String?
    @State private var season: String?
    @State private var massPart: String?
    @State private var showsFilters = false
    @State private var showsLanguages = false
    @State private var openDownloadsAfterLanguage = false
    @State private var scrollResetToken = 0
    @State private var selectedID: String?
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar(isTabRoot: true)
            if splitsColumns {
                HStack(spacing: 0) {
                    listColumn
                    Rectangle()
                        .fill(palette.border.color)
                        .frame(width: 1)
                    detailColumn
                }
            } else {
                listColumn
            }
        }
        .background(palette.background.color)
        .navigationTitle("Hymns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsFilters) {
            HymnFilterSheet(
                season: $season,
                massPart: $massPart
            )
        }
        .sheet(isPresented: $showsLanguages, onDismiss: openDownloadsIfNeeded) {
            HymnLanguageSheet(
                languages: model.languages,
                catalogues: packStore.packs,
                selected: activeLanguage,
                onSelect: { code in
                    // The list refilters in a moment now, so there is nothing to wait for.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        language = code
                    }
                },
                onDownload: { openDownloadsAfterLanguage = true }
            )
        }
        .onChange(of: language) { _, _ in applyFilters() }
        .onChange(of: season) { _, _ in applyFilters() }
        .onChange(of: massPart) { _, _ in applyFilters() }
        .onChange(of: packs.ids) { _, _ in applyFilters() }
        .onChange(of: packStore.packs) { _, _ in model.refilter(filterInputs) }
        .task {
            // The task restarts each time the tab appears. The list loads once.
            guard !model.isLoaded else { return }
            await loadCatalogue()
        }
        .onReceive(NotificationCenter.default.publisher(for: .hymnStoreDidChange)) { _ in
            Task { await loadCatalogue() }
        }
    }

    private var listColumn: some View {
        // Read once per pass. The rows below take these as plain values.
        let saved = savedIDs
        let selectedRow = splitsColumns ? activeID : nil
        return VStack(alignment: .leading, spacing: splitsColumns ? 14 : 12) {
            listHeader
            languageButton
            searchField
            if splitsColumns {
                wideCountRow
            } else {
                phoneCountRow
            }
            filterBar
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: splitsColumns ? 8 : 0) {
                        if model.isLoaded, model.rows.isEmpty {
                            Text("No hymns match.")
                                .font(AppFont.body())
                                .foregroundStyle(palette.mutedForeground.color)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(model.rows) { item in
                                HymnListRow(
                                    item: item,
                                    isSaved: saved.contains(item.id),
                                    isSelected: item.id == selectedRow,
                                    splitsColumns: splitsColumns,
                                    palette: palette,
                                    onOpen: open,
                                    onToggleSaved: toggleSaved
                                )
                                .equatable()
                            }
                        }
                        if !splitsColumns {
                            Text("Search is limited to the hymn catalogue.")
                                .font(AppFont.interface(size: 12))
                                .foregroundStyle(palette.mutedForeground.color)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.top, 18)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .onChange(of: scrollResetToken) { _, _ in
                    guard let first = model.rows.first?.id else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(first, anchor: .top)
                    }
                }
            }
        }
        .padding(.horizontal, splitsColumns ? 22 : 20)
        .padding(.top, splitsColumns ? 22 : 8)
        .frame(maxWidth: splitsColumns ? 440 : .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.background.color)
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if splitsColumns {
                Text("YOUR HYMN CATALOGUES")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.emphasis.color)
            }
            HStack(alignment: .center, spacing: 8) {
                Text("Hymns")
                    .font(AppFont.heading(size: splitsColumns ? 34 : 40))
                    .foregroundStyle(palette.foreground.color)
                Spacer(minLength: 8)
                if !splitsColumns {
                    Button {
                        showsFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(palette.foreground.color)
                            .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("Filter hymns")
                }
            }
            Text(splitsColumns ? "Search by number, title, or any text." : "Hymns · Search by number, title, or text.")
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
        }
    }

    private var languageButton: some View {
        Button {
            showsLanguages = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
                    .frame(width: 24, height: 24)
                Text(languageButtonTitle)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Hymn language")
        .accessibilityValue(languageButtonTitle)
    }

    private var phoneCountRow: some View {
        HStack {
            Text("Hymns catalogue")
                .font(AppFont.interface(size: 13))
                .foregroundStyle(palette.mutedForeground.color)
            Spacer(minLength: 8)
            Text(HymnLabels.resultCount(filtered.count))
                .font(AppFont.interface(size: 13))
                .foregroundStyle(palette.mutedForeground.color)
        }
    }

    private var wideCountRow: some View {
        HStack(spacing: 16) {
            Text("HYMNS")
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.mutedForeground.color)
            Spacer(minLength: 8)
            Text(HymnLabels.itemCount(filtered.count))
                .font(AppFont.interface(size: 13))
                .foregroundStyle(palette.mutedForeground.color)
        }
    }

    private var detailColumn: some View {
        Group {
            if let id = activeID {
                HymnDetailView(id: id, showsChrome: false)
            } else {
                Text("Choose a hymn.")
                    .font(AppFont.body())
                    .foregroundStyle(palette.mutedForeground.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.mutedForeground.color)
            TextField(splitsColumns ? "Number, title, or indexed text" : "Search hymn number, title, or text", text: $query)
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.foreground.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if splitsColumns {
                Text(HymnLabels.resultCount(filtered.count))
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: ControlMetrics.minimumHeight)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search hymns")
        .onChange(of: query) { _, newValue in
            debounce?.cancel()
            debounce = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedQuery = newValue
                applyFilters()
            }
        }
    }

    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            filterBarRow
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 8) {
                filterButton
                if filtersActive {
                    chipRow
                }
            }
        }
    }

    private var filterBarRow: some View {
        HStack(spacing: 8) {
            filterButton
            if filtersActive {
                chipRow
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            if let season {
                activeFilterChip(HymnLabels.token(season)) { self.season = nil }
            }
            if let massPart {
                activeFilterChip(HymnLabels.token(massPart)) { self.massPart = nil }
            }
        }
    }

    private func activeFilterChip(_ title: String, clear: @escaping () -> Void) -> some View {
        Button(action: clear) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(AppFont.interface(size: 14, weight: .semibold))
            .foregroundStyle(palette.foreground.color)
            .padding(.horizontal, 12)
            .frame(minHeight: ControlMetrics.minimumHeight)
            .background(palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Remove \(title)")
    }

    private var filterButton: some View {
        Button {
            showsFilters = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                Text(filtersActive ? "Filters · Active" : "Filters")
                    .font(AppFont.interface(size: 14, weight: .semibold))
            }
            .foregroundStyle(palette.foreground.color)
            .padding(.horizontal, 14)
            .frame(minHeight: ControlMetrics.minimumHeight)
            .background(palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Filter hymns")
    }

    private func loadCatalogue() async {
        await model.load(from: modelContext.container) { filterInputs }
    }

    /// The values the list is derived from. Pass them to the model when any of them changes.
    private var filterInputs: HymnListModel.Inputs {
        HymnListModel.Inputs(
            installed: Set(packs.hymnLanguages),
            language: language,
            season: season,
            massPart: massPart,
            query: debouncedQuery,
            catalogues: packStore.packs
        )
    }

    /// A filter changed. Refilter once, then show the first hymn.
    private func applyFilters() {
        model.refilter(filterInputs)
        scrollResetToken &+= 1
    }

    /// Nil shows every catalogue. A stored choice is kept only while that language is on the device.
    private var activeLanguage: String? { model.activeLanguage }

    private var languageButtonTitle: String {
        guard let activeLanguage else { return "All languages" }
        return HymnLanguage.name(for: activeLanguage, in: packStore.packs)
    }

    /// Stored by the model. Reading it does not filter the catalogue.
    private var filtered: [HymnSummary] { model.filtered }

    private var savedIDs: Set<String> {
        Set(bookmarks.map(\.hymnId))
    }

    private var filtersActive: Bool {
        season != nil || massPart != nil
    }

    private func openDownloadsIfNeeded() {
        guard openDownloadsAfterLanguage else { return }
        openDownloadsAfterLanguage = false
        navigation.path.append(AppRoute.downloads)
    }

    private var activeID: String? {
        if let selectedID, filtered.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return splitsColumns ? filtered.first?.id : nil
    }

    private func open(_ id: String) {
        if splitsColumns {
            selectedID = id
        } else {
            navigation.path.append(AppRoute.hymn(id: id))
        }
    }

    private func toggleSaved(_ id: String) {
        guard let hymn = HymnImporter.record(id: id, in: modelContext) else { return }
        try? HymnImporter.toggleBookmark(hymn, in: modelContext)
    }
}
