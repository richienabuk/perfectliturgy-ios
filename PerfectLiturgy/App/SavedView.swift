import SwiftData
import SwiftUI

struct SavedRow: Equatable, Identifiable {
    var id: String
    var itemId: String
    var type: String
    var title: String
    var detail: String
    var opens: Bool
    var route: AppRoute?
    var language: String?
}

enum SavedRows {
    static let heading = "Saved"
    static let support = "Keep what you want close at hand."

    static func emptyNote(signedIn: Bool) -> String {
        if signedIn {
            "Save a hymn, a prayer, or a litany from its page. It syncs with your Account when you're online."
        } else {
            "Save a hymn, a prayer, or a litany from its page. It stays on this device and opens here."
        }
    }

    /// An installed hymn opens. A missing hymn keeps the stored title and stays closed.
    static func row(bookmark: HymnBookmark, hymn: HymnRecord?, installed: Set<String>, catalogues: [PackRecord] = PackSeed.rows) -> SavedRow {
        let language = hymn?.language ?? bookmark.language
        let packInstalled = !language.isEmpty && installed.contains(ContentPack.hymnID(for: language))
        if let hymn, packInstalled {
            return SavedRow(
                id: bookmark.hymnId,
                itemId: bookmark.hymnId,
                type: BookmarkType.hymns,
                title: hymn.title,
                detail: detail(language: hymn.language, massParts: hymn.massParts, catalogues: catalogues),
                opens: true,
                route: .hymn(id: bookmark.hymnId),
                language: hymn.language
            )
        }
        let message = if language.isEmpty || packInstalled {
            "Not on this device"
        } else {
            "Hymn pack removed from this device"
        }
        return SavedRow(
            id: bookmark.hymnId,
            itemId: bookmark.hymnId,
            type: BookmarkType.hymns,
            title: bookmark.titleSnapshot,
            detail: message,
            opens: false,
            route: nil,
            language: language
        )
    }

    /// An installed prayer or litany opens in the language it was saved in.
    static func row(
        bookmark: DevotionBookmark,
        located: LocatedDevotion?,
        installed: Set<String>,
        catalogues: [PackRecord] = PackSeed.rows
    ) -> SavedRow {
        let packInstalled = !bookmark.language.isEmpty && installed.contains("\(bookmark.type)-\(bookmark.language)")
        if let located, bookmark.language.isEmpty || packInstalled {
            let name = PackLanguages.language(code: located.language, type: bookmark.type, in: catalogues).packName
            return SavedRow(
                id: bookmark.key,
                itemId: bookmark.itemId,
                type: bookmark.type,
                title: located.title,
                detail: name,
                opens: true,
                route: route(type: bookmark.type, id: bookmark.itemId),
                language: located.language
            )
        }
        let message = if bookmark.language.isEmpty || packInstalled {
            "Not on this device"
        } else if bookmark.type == BookmarkType.prayers {
            "Prayer pack removed from this device"
        } else if bookmark.type == BookmarkType.litanies {
            "Litany pack removed from this device"
        } else {
            "Not on this device"
        }
        return SavedRow(
            id: bookmark.key,
            itemId: bookmark.itemId,
            type: bookmark.type,
            title: bookmark.titleSnapshot,
            detail: message,
            opens: false,
            route: nil,
            language: bookmark.language
        )
    }

    static func route(type: String, id: String) -> AppRoute? {
        switch type {
        case BookmarkType.prayers: .prayer(id: id)
        case BookmarkType.litanies: .litany(id: id)
        default: nil
        }
    }

    static func removeLabel(type: String) -> String {
        switch type {
        case BookmarkType.prayers: "Remove saved prayer"
        case BookmarkType.litanies: "Remove saved litany"
        default: "Remove saved hymn"
        }
    }

    /// Newest first. `limit` keeps the home list to five. Saved passes no limit.
    static func rows(
        hymns: [HymnBookmark],
        devotions: [DevotionBookmark],
        hymnLookup: (String) -> HymnRecord?,
        located: (DevotionBookmark) -> LocatedDevotion?,
        installed: Set<String>,
        catalogues: [PackRecord] = PackSeed.rows,
        limit: Int? = nil
    ) -> [SavedRow] {
        enum Source {
            case hymn(HymnBookmark)
            case devotion(DevotionBookmark)
        }
        var dated: [(Date, String, Source)] = []
        dated.reserveCapacity(hymns.count + devotions.count)
        for bookmark in hymns {
            dated.append((bookmark.createdAt, bookmark.hymnId, .hymn(bookmark)))
        }
        for bookmark in devotions {
            dated.append((bookmark.createdAt, bookmark.key, .devotion(bookmark)))
        }
        dated.sort { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
            return lhs.1 < rhs.1
        }
        let chosen = dated.prefix(limit ?? dated.count)
        return chosen.map { item in
            switch item.2 {
            case .hymn(let bookmark):
                row(
                    bookmark: bookmark,
                    hymn: hymnLookup(bookmark.hymnId),
                    installed: installed,
                    catalogues: catalogues
                )
            case .devotion(let bookmark):
                row(
                    bookmark: bookmark,
                    located: located(bookmark),
                    installed: installed,
                    catalogues: catalogues
                )
            }
        }
    }

    static func detail(language: String, massParts: [String], catalogues: [PackRecord] = PackSeed.rows) -> String {
        var parts = [HymnLanguage.catalogueName(for: language, in: catalogues)]
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
    @Environment(LanguageSelection.self) private var selection
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \HymnBookmark.createdAt, order: .reverse) private var bookmarks: [HymnBookmark]
    @Query(sort: \DevotionBookmark.createdAt, order: .reverse) private var devotions: [DevotionBookmark]
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
        .onChange(of: devotions.map(\.key)) { _, _ in reloadRows() }
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
            catalogues: PackCatalogStore.shared.packs
        )
    }

    private func savedRow(_ row: SavedRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if row.opens, let route = row.route {
                Button {
                    if let language = row.language, let kind = DevotionKind(rawValue: row.type) {
                        selection.select(language, for: kind)
                    }
                    navigation.path.append(route)
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
            if row.type == BookmarkType.hymns {
                try? HymnImporter.removeBookmark(hymnID: row.itemId, in: modelContext)
            } else {
                try? DevotionBookmarks.remove(type: row.type, id: row.itemId, in: modelContext)
            }
        } label: {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundStyle(palette.emphasis.color)
                .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(SavedRows.removeLabel(type: row.type))
        .accessibilityIdentifier("saved.remove.\(row.id)")
    }
}

#Preview {
    SavedView()
        .modelContainer(try! HymnStore.make(inMemory: true))
        .environment(AppNavigation())
        .environment(InstalledPacks(defaults: UserDefaults(suiteName: "saved-preview") ?? .standard))
        .environment(AppSession(token: nil, store: MemorySessionStore()))
        .environment(LanguageSelection(defaults: UserDefaults(suiteName: "saved-preview") ?? .standard))
        .resolvePalette()
}
