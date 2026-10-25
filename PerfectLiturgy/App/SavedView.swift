import SwiftData
import SwiftUI

struct SavedRow: Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var opens: Bool
}

enum SavedRows {
    static let heading = "Saved"
    static let support = "Keep what you want close at hand."

    static func emptyNote(signedIn: Bool) -> String {
        if signedIn {
            "Save a hymn from its page. It syncs with your Account when you're online."
        } else {
            "Save a hymn from its page. It stays on this device and opens here."
        }
    }

    /// An installed hymn opens. A missing hymn keeps the stored title and stays closed.
    static func row(bookmark: HymnBookmark, hymn: HymnRecord?, installed: Set<String>) -> SavedRow {
        let language = hymn?.language ?? bookmark.language
        let packInstalled = !language.isEmpty && installed.contains(ContentPack.hymnID(for: language))
        if let hymn, packInstalled {
            return SavedRow(
                id: bookmark.hymnId,
                title: hymn.title,
                detail: detail(language: hymn.language, massParts: hymn.massParts),
                opens: true
            )
        }
        let message = if language.isEmpty || packInstalled {
            "Not on this device"
        } else {
            "Hymn pack removed from this device"
        }
        return SavedRow(id: bookmark.hymnId, title: bookmark.titleSnapshot, detail: message, opens: false)
    }

    static func detail(language: String, massParts: [String]) -> String {
        var parts = [HymnLanguage.catalogueName(for: language)]
        if let first = massParts.first, !first.isEmpty {
            parts.append(HymnLabels.token(first))
        }
        return parts.joined(separator: " · ")
    }
}

struct SavedView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppNavigation.self) private var navigation
    @Environment(InstalledPacks.self) private var packs
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \HymnBookmark.createdAt, order: .reverse) private var bookmarks: [HymnBookmark]
    @State private var savedRows: [SavedRow] = []

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar(isTabRoot: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if savedRows.isEmpty {
                        Text(SavedRows.emptyNote(signedIn: session.isSignedIn))
                            .font(AppFont.body())
                            .foregroundStyle(palette.mutedForeground.color)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(savedRows.enumerated()), id: \.element.id) { index, row in
                                savedRow(row)
                                if index < savedRows.count - 1 {
                                    Rectangle()
                                        .fill(palette.border.color)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, isWide ? 28 : 20)
                .padding(.vertical, 24)
                .frame(maxWidth: isWide ? 840 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.background.color)
        .navigationTitle(SavedRows.heading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { reloadRows() }
        .onChange(of: bookmarks.map(\.hymnId)) { _, _ in reloadRows() }
        .onChange(of: packs.ids) { _, _ in reloadRows() }
        .onReceive(NotificationCenter.default.publisher(for: .hymnStoreDidChange)) { _ in
            reloadRows()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            PLHeading(lead: SavedRows.heading, size: 40)
            Text(SavedRows.support)
                .font(AppFont.body())
                .foregroundStyle(palette.mutedForeground.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func reloadRows() {
        savedRows = bookmarks.map { bookmark in
            SavedRows.row(
                bookmark: bookmark,
                hymn: HymnImporter.record(id: bookmark.hymnId, in: modelContext),
                installed: packs.ids
            )
        }
    }

    private func savedRow(_ row: SavedRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if row.opens {
                Button {
                    navigation.path.append(AppRoute.hymn(id: row.id))
                } label: {
                    rowLabel(row)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(row.title)")
                .accessibilityIdentifier("saved.open.\(row.id)")
            } else {
                rowLabel(row)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.title). \(row.detail)")
                    .accessibilityIdentifier("saved.closed.\(row.id)")
            }
            removeButton(row)
            if row.opens {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: ControlMetrics.minimumHeight)
    }

    private func rowLabel(_ row: SavedRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func removeButton(_ row: SavedRow) -> some View {
        Button {
            try? HymnImporter.removeBookmark(hymnID: row.id, in: modelContext)
        } label: {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundStyle(palette.emphasis.color)
                .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Remove saved hymn")
        .accessibilityIdentifier("saved.remove.\(row.id)")
    }
}

#Preview {
    SavedView()
        .modelContainer(try! HymnStore.make(inMemory: true))
        .environment(AppNavigation())
        .environment(InstalledPacks(defaults: UserDefaults(suiteName: "saved-preview") ?? .standard))
        .environment(AppSession(token: nil, store: MemorySessionStore()))
        .resolvePalette()
}
