import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Query(sort: \HymnBookmark.createdAt, order: .reverse) private var bookmarks: [HymnBookmark]
    @Environment(\.modelContext) private var modelContext
    @State private var savedCatalogue: String?

    private var page: TodayPage {
        TodayPageBuilder.page(for: CivilDate(Date()), lectionary: TodayLibrary.lectionary)
    }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
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
        .task { loadSaved() }
        .onChange(of: bookmarks.map(\.hymnId)) { _, _ in loadSaved() }
        .onReceive(NotificationCenter.default.publisher(for: .hymnStoreDidChange)) { _ in
            loadSaved()
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
            if let bookmark = bookmarks.first {
                savedCard(bookmark)
            } else {
                emptySavedCard
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

    private func savedCard(_ bookmark: HymnBookmark) -> some View {
        Button {
            navigation.path.append(AppRoute.hymn(id: bookmark.hymnId))
        } label: {
            HStack(spacing: 12) {
                markTile(systemName: "bookmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.titleSnapshot)
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                        .multilineTextAlignment(.leading)
                    if let savedCatalogue {
                        Text(savedCatalogue)
                            .font(AppFont.interface(size: 13))
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .background(palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func loadSaved() {
        guard let bookmark = bookmarks.first else {
            savedCatalogue = nil
            return
        }
        guard let hymn = HymnImporter.record(id: bookmark.hymnId, in: modelContext) else {
            savedCatalogue = nil
            return
        }
        savedCatalogue = HymnLanguage.catalogueName(for: hymn.language)
    }

    private var emptySavedCard: some View {
        Button {
            navigation.tab = .hymns
        } label: {
            HStack(spacing: 12) {
                markTile(systemName: "bookmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text("No hymn is saved yet.")
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    Text("Open hymns")
                        .font(AppFont.interface(size: 13))
                        .foregroundStyle(palette.mutedForeground.color)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
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
        .resolvePalette()
}
