import SwiftData
import SwiftUI

struct HymnsView: View {
    init(initialQuery: String = "") {
        _query = State(initialValue: initialQuery)
        _debouncedQuery = State(initialValue: initialQuery)
    }

    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\HymnRecord.language),
        SortDescriptor(\HymnRecord.hymnNumber),
    ]) private var hymns: [HymnRecord]
    @Query private var bookmarks: [HymnBookmark]

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var language: String?
    @State private var season: String?
    @State private var massPart: String?
    @State private var showsFilters = false
    @State private var visibleCount = HymnFilter.pageSize
    @State private var selectedID: String?
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            if isWide {
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
                language: $language,
                season: $season,
                massPart: $massPart,
                languages: HymnLanguage.ordered(hymns.map(\.language)),
                matchCount: filtered.count
            )
        }
        .onChange(of: language) { _, _ in visibleCount = HymnFilter.pageSize }
        .onChange(of: season) { _, _ in visibleCount = HymnFilter.pageSize }
        .onChange(of: massPart) { _, _ in visibleCount = HymnFilter.pageSize }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: isWide ? 14 : 12) {
            listHeader
            searchField
            if isWide {
                wideCountRow
            } else {
                phoneCountRow
                filterButton
            }
            ScrollView {
                LazyVStack(spacing: isWide ? 8 : 0) {
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
                    if !isWide {
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
        .padding(.horizontal, isWide ? 22 : 20)
        .padding(.top, isWide ? 22 : 8)
        .frame(maxWidth: isWide ? 440 : .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.background.color)
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isWide {
                Text("YOUR HYMN CATALOGUES")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.emphasis.color)
            }
            HStack(alignment: .center, spacing: 8) {
                Text("Hymns")
                    .font(AppFont.heading(size: isWide ? 34 : 40))
                    .foregroundStyle(palette.foreground.color)
                Spacer(minLength: 8)
                if !isWide {
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
            Text(isWide ? "Search by number, title, or any text." : "Hymns · Search by number, title, or text.")
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
        }
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
            Button {
                showsFilters = true
            } label: {
                Text("Filters")
                    .font(AppFont.interface(size: 13, weight: .semibold))
                    .foregroundStyle(filtersActive ? palette.primary.color : palette.mutedForeground.color)
                    .frame(minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Filter hymns")
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
            TextField(isWide ? "Number, title, or indexed text" : "Search hymn number, title, or text", text: $query)
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.foreground.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if isWide {
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

    private var filterButton: some View {
        Button {
            showsFilters = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                Text("Filters")
                    .font(AppFont.interface(size: 14, weight: .semibold))
            }
            .foregroundStyle(filtersActive ? palette.primaryForeground.color : palette.foreground.color)
            .padding(.horizontal, 14)
            .frame(minHeight: ControlMetrics.minimumHeight)
            .background(filtersActive ? palette.primary.color : palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Filter hymns")
    }

    private func row(_ hymn: HymnRecord) -> some View {
        let saved = savedIDs.contains(hymn.id)
        let selected = isWide && hymn.id == activeID
        return HStack(alignment: .center, spacing: 12) {
            Button {
                open(hymn)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    if isWide {
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
            bookmarkButton(saved: saved, hymn: hymn)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.mutedForeground.color)
        }
        .padding(.horizontal, isWide ? 10 : 0)
        .padding(.vertical, isWide ? 10 : 12)
        .background(selected ? palette.card.color : Color.clear, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if !isWide {
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

    private func bookmarkButton(saved: Bool, hymn: HymnRecord) -> some View {
        Button {
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

    private func rowLine(_ hymn: HymnRecord) -> String {
        HymnLabels.rowLine(language: hymn.language, seasons: hymn.seasons, massParts: hymn.massParts)
    }

    private var filter: HymnFilter {
        HymnFilter(text: debouncedQuery, language: language, season: season, massPart: massPart)
    }

    private var filtered: [HymnRecord] {
        hymns.filter { HymnSearch.matches($0.summary, filter: filter) }
    }

    private var visible: [HymnRecord] {
        Array(filtered.prefix(visibleCount))
    }

    private var savedIDs: Set<String> {
        Set(bookmarks.map(\.hymnId))
    }

    private var filtersActive: Bool {
        language != nil || season != nil || massPart != nil
    }

    private var activeID: String? {
        if let selectedID, filtered.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return isWide ? filtered.first?.id : nil
    }

    private func open(_ hymn: HymnRecord) {
        if isWide {
            selectedID = hymn.id
        } else {
            navigation.path.append(AppRoute.hymn(id: hymn.id))
        }
    }
}
