import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Query(sort: \HymnBookmark.createdAt, order: .reverse) private var bookmarks: [HymnBookmark]
    @Query(sort: \DevotionBookmark.createdAt, order: .reverse) private var devotions: [DevotionBookmark]
    @Environment(\.modelContext) private var modelContext
    @State private var savedRows: [SavedRow] = []

    private var page: TodayPage {
        TodayPageBuilder.page(for: CivilDate(Date()), lectionary: TodayLibrary.lectionary)
    }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar(isTabRoot: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    LiturgicalBanner(title: page.title, weekMark: page.weekMark)
                    readings
                    forLater
                }
                .padding(.horizontal, isWide ? 28 : 20)
                .padding(.vertical, 24)
                .frame(maxWidth: isWide ? 840 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.background.color)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { reloadSaved() }
        .onChange(of: bookmarks.map(\.hymnId)) { _, _ in reloadSaved() }
        .onChange(of: devotions.map(\.key)) { _, _ in reloadSaved() }
        .onChange(of: packs.ids) { _, _ in reloadSaved() }
        .onReceive(NotificationCenter.default.publisher(for: .hymnStoreDidChange)) { _ in
            reloadSaved()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            PLEyebrow(text: page.dateLine)
            PLHeading(lead: "Readings and Hymns", emphasis: "for Mass today.", size: 40)
            Text("Readings and saved Hymns in your languages.")
                .font(AppFont.body())
                .foregroundStyle(palette.mutedForeground.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readings: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Today's readings") {
                navigation.tab = .readings
            } link: {
                "Open readings"
            }
            VStack(spacing: 0) {
                ForEach(Array(page.readings.enumerated()), id: \.element.id) { index, reading in
                    readingRow(reading)
                    if index < page.readings.count - 1 {
                        Rectangle()
                            .fill(palette.border.color)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, isWide ? 4 : 0)
        }
    }

    private var forLater: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("For later") {
                navigation.tab = .saved
            } link: {
                "See saved"
            }
            if savedRows.isEmpty {
                emptySavedCard
            } else {
                VStack(spacing: 8) {
                    ForEach(savedRows) { row in
                        savedCard(row)
                    }
                }
            }
        }
    }

    private func readingRow(_ reading: TodayReading) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(reading.label)
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
                .layoutPriority(1)
            if !reading.reference.isEmpty {
                Text(reading.reference)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: ControlMetrics.minimumHeight, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: String, action: @escaping () -> Void, link: () -> String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(AppFont.title(size: 26))
                .foregroundStyle(palette.foreground.color)
            Spacer(minLength: 8)
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(link())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(AppFont.interface(size: 15, weight: .semibold))
                .foregroundStyle(palette.foreground.color)
                .frame(minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    private func savedCard(_ row: SavedRow) -> some View {
        Group {
            if row.opens, let route = row.route {
                Button {
                    if let language = row.language, let kind = DevotionKind(rawValue: row.type) {
                        selection.select(language, for: kind)
                    }
                    navigation.path.append(route)
                } label: {
                    savedLabel(row)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Open \(row.title)")
            } else {
                savedLabel(row)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.title). \(row.detail)")
            }
        }
    }

    private func savedLabel(_ row: SavedRow) -> some View {
        HStack(spacing: 12) {
            markTile(systemName: "bookmark")
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(AppFont.interface(size: 16, weight: .semibold))
                    .foregroundStyle(row.opens ? palette.foreground.color : palette.mutedForeground.color)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.detail)
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if row.opens {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
        .background(palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private func reloadSaved() {
        savedRows = SavedRows.rows(
            hymns: bookmarks,
            devotions: devotions,
            hymnLookup: { HymnImporter.record(id: $0, in: modelContext) },
            located: { bookmark in
                DevotionBookmarks.locate(
                    type: bookmark.type,
                    id: bookmark.itemId,
                    language: bookmark.language,
                    installed: packs.ids
                )
            },
            installed: packs.ids,
            catalogues: PackCatalogStore.shared.packs,
            limit: 5
        )
    }

    private var emptySavedCard: some View {
        Text("Save a hymn, a prayer, or a litany from its page.")
            .font(AppFont.body())
            .foregroundStyle(palette.mutedForeground.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func markTile(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(palette.emphasis.color)
            .frame(width: 36, height: 36)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}

private enum TodayLibrary {
    static let lectionary = Lectionary.load()
}

#Preview {
    TodayView()
        .modelContainer(try! HymnStore.make(inMemory: true))
        .environment(DesignPreferences())
        .environment(AppNavigation())
        .environment(InstalledPacks(defaults: UserDefaults(suiteName: "today-preview") ?? .standard))
        .environment(LanguageSelection(defaults: UserDefaults(suiteName: "today-preview") ?? .standard))
        .resolvePalette()
}
