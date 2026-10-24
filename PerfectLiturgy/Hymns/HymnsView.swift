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

    @State private var catalogue: [HymnSummary] = []
    @Query private var bookmarks: [HymnBookmark]

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var language: String?
    @State private var season: String?
    @State private var massPart: String?
    @State private var showsFilters = false
    @State private var showsLanguages = false
    @State private var openDownloadsAfterLanguage = false
    @State private var visibleCount = HymnFilter.pageSize
    @State private var selectedID: String?
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
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
                languages: languages,
                selected: activeLanguage,
                onSelect: { language = $0 },
                onDownload: { openDownloadsAfterLanguage = true }
            )
        }
        .onChange(of: language) { _, _ in visibleCount = HymnFilter.pageSize }
        .onChange(of: season) { _, _ in visibleCount = HymnFilter.pageSize }
        .onChange(of: massPart) { _, _ in visibleCount = HymnFilter.pageSize }
        .task { loadCatalogue() }
        .onReceive(NotificationCenter.default.publisher(for: .hymnStoreDidChange)) { _ in
            loadCatalogue()
        }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: splitsColumns ? 14 : 12) {
            listHeader
            languageButton
            searchField
            if splitsColumns {
                wideCountRow
            } else {
                phoneCountRow
            }
            filterBar
            ScrollView {
                LazyVStack(spacing: splitsColumns ? 8 : 0) {
                    if filtered.isEmpty {
                        Text("No hymns match.")
                            .font(AppFont.body())
                            .foregroundStyle(palette.mutedForeground.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(visible) { hymn in
                            row(hymn)
                                .onAppear {
                                    if hymn.id == visible.last?.id, visibleCount < filtered.count {
                                        visibleCount += HymnFilter.pageSize
                                    }
                                }
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
                visibleCount = HymnFilter.pageSize
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

    private func row(_ hymn: HymnSummary) -> some View {
        let saved = savedIDs.contains(hymn.id)
        let selected = splitsColumns && hymn.id == activeID
        return HStack(alignment: .center, spacing: 12) {
            Button {
                open(hymn)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    if splitsColumns {
                        musicMark
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hymn.title)
                                .font(AppFont.interface(size: 16, weight: .semibold))
                                .foregroundStyle(palette.foreground.color)
                                .multilineTextAlignment(.leading)
                            Text(rowLine(hymn))
                                .font(AppFont.interface(size: 13))
                                .foregroundStyle(palette.mutedForeground.color)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(String(hymn.hymnNumber))
                            .font(AppFont.interface(size: 14))
                            .foregroundStyle(palette.mutedForeground.color)
                    } else {
                        numberTile(hymn.hymnNumber)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hymn.title)
                                .font(AppFont.interface(size: 16, weight: .semibold))
                                .foregroundStyle(palette.foreground.color)
                                .multilineTextAlignment(.leading)
                            Text(rowLine(hymn))
                                .font(AppFont.interface(size: 13))
                                .foregroundStyle(palette.mutedForeground.color)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(hymn.hymnNumber), \(hymn.title)")
            bookmarkButton(saved: saved, id: hymn.id)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.mutedForeground.color)
        }
        .padding(.horizontal, splitsColumns ? 10 : 0)
        .padding(.vertical, splitsColumns ? 10 : 12)
        .background(selected ? palette.card.color : Color.clear, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if !splitsColumns {
                Rectangle()
                    .fill(palette.border.color)
                    .frame(height: 1)
            }
        }
    }

    private func numberTile(_ number: Int) -> some View {
        Text(String(number))
            .font(AppFont.title(size: 22))
            .foregroundStyle(palette.emphasis.color)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .frame(width: 52, height: 52)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
    }

    private var musicMark: some View {
        Image(systemName: "music.note")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.emphasis.color)
            .frame(width: 36, height: 36)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
    }

    private func bookmarkButton(saved: Bool, id: String) -> some View {
        Button {
            guard let hymn = HymnImporter.record(id: id, in: modelContext) else { return }
            try? HymnImporter.toggleBookmark(hymn, in: modelContext)
        } label: {
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16))
                .foregroundStyle(saved ? palette.emphasis.color : palette.foreground.color)
                .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(saved ? "Remove saved hymn" : "Save hymn")
    }

    private func rowLine(_ hymn: HymnSummary) -> String {
        HymnLabels.rowLine(language: hymn.language, seasons: hymn.seasons, massParts: hymn.massParts)
    }

    private func loadCatalogue() {
        catalogue = HymnImporter.catalogue(in: modelContext)
    }

    private var languages: [String] {
        let installed = Set(packs.hymnLanguages)
        return HymnLanguage.ordered(catalogue.map(\.language).filter { installed.contains($0) })
    }

    /// Nil shows every catalogue. A stored choice is kept only while that language is on the device.
    private var activeLanguage: String? {
        guard let language, languages.contains(language) else { return nil }
        return language
    }

    private var languageButtonTitle: String {
        guard let activeLanguage else { return "All languages" }
        return HymnLanguage.name(for: activeLanguage)
    }

    private var filter: HymnFilter {
        HymnFilter(text: debouncedQuery, language: activeLanguage, season: season, massPart: massPart)
    }

    private var filtered: [HymnSummary] {
        let installed = Set(packs.hymnLanguages)
        return catalogue.filter { installed.contains($0.language) && HymnSearch.matches($0, filter: filter) }
    }

    private var visible: [HymnSummary] {
        Array(filtered.prefix(visibleCount))
    }

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

    private func open(_ hymn: HymnSummary) {
        if splitsColumns {
            selectedID = hymn.id
        } else {
            navigation.path.append(AppRoute.hymn(id: hymn.id))
        }
    }
}
