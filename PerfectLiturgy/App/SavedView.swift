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

struct SavedGroup: Equatable, Identifiable {
    var type: String
    var title: String
    var rows: [SavedRow]

    var id: String { type }
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
    static func hymnRow(bookmark: Bookmark, hymn: HymnRecord?, installed: Set<String>, catalogues: [PackRecord] = PackSeed.rows) -> SavedRow {
        let language = hymn?.language ?? bookmark.language
        let packInstalled = !language.isEmpty && installed.contains(ContentPack.hymnID(for: language))
        if let hymn, packInstalled {
            return SavedRow(
                id: bookmark.key,
                itemId: bookmark.itemId,
                type: bookmark.type,
                title: hymn.title,
                detail: detail(language: hymn.language, massParts: hymn.massParts, catalogues: catalogues),
                opens: true,
                route: .hymn(id: bookmark.itemId),
                language: hymn.language
            )
        }
        let message = if language.isEmpty || packInstalled {
            "Not on this device"
        } else {
            "Hymn pack removed from this device"
        }
        return closedRow(bookmark, detail: message, language: language)
    }

    /// An installed prayer or litany opens in the language it was saved in.
    static func devotionRow(
        bookmark: Bookmark,
        located: LocatedDevotion?,
        installed: Set<String>,
        catalogues: [PackRecord] = PackSeed.rows
    ) -> SavedRow {
        let packInstalled = !bookmark.language.isEmpty && installed.contains("\(bookmark.type)-\(bookmark.language)")
        let locatedInstalled = located.map { installed.contains("\(bookmark.type)-\($0.language)") } ?? false
        if let located, bookmark.language.isEmpty || packInstalled || locatedInstalled {
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
        return closedRow(bookmark, detail: message, language: bookmark.language)
    }

    private static func closedRow(_ bookmark: Bookmark, detail: String, language: String) -> SavedRow {
        SavedRow(
            id: bookmark.key,
            itemId: bookmark.itemId,
            type: bookmark.type,
            title: bookmark.titleSnapshot,
            detail: detail,
            opens: false,
            route: nil,
            language: language
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
        _ bookmarks: [Bookmark],
        hymnLookup: (String) -> HymnRecord?,
        located: (Bookmark) -> LocatedDevotion?,
        installed: Set<String>,
        catalogues: [PackRecord] = PackSeed.rows,
        limit: Int? = nil
    ) -> [SavedRow] {
        let newest = bookmarks.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.key < rhs.key
        }
        return newest.prefix(limit ?? newest.count).map { bookmark in
            if bookmark.type == BookmarkType.hymns {
                hymnRow(bookmark: bookmark, hymn: hymnLookup(bookmark.itemId), installed: installed, catalogues: catalogues)
            } else {
                devotionRow(bookmark: bookmark, located: located(bookmark), installed: installed, catalogues: catalogues)
            }
        }
    }

    static let groupOrder: [(type: String, title: String)] = [
        (BookmarkType.hymns, "Hymns"),
        (BookmarkType.prayers, "Prayers"),
        (BookmarkType.litanies, "Litanies"),
    ]

    /// Saved shows one group per type, in a fixed order. Each keeps the newest-first order of `rows`.
    static func groups(_ rows: [SavedRow]) -> [SavedGroup] {
        groupOrder.compactMap { entry in
            let inGroup = rows.filter { $0.type == entry.type }
            return inGroup.isEmpty ? nil : SavedGroup(type: entry.type, title: entry.title, rows: inGroup)
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

/// A bookmark just removed from Saved, kept for a few seconds so Undo can put it back.
private struct RemovedBookmark: Equatable {
    var draft: BookmarkDraft
    var language: String
    var title: String
}

struct SavedView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppNavigation.self) private var navigation
    @Environment(InstalledPacks.self) private var packs
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Environment(LanguageSelection.self) private var selection
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @State private var savedRows: [SavedRow] = []
    @State private var undo: RemovedBookmark?
    @State private var undoTimer: Task<Void, Never>?

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
                        ForEach(SavedRows.groups(savedRows)) { group in
                            groupSection(group)
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
        .overlay(alignment: .bottom) {
            if let undo {
                undoBar(undo)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: undo)
        .navigationTitle(SavedRows.heading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { reloadRows() }
        .onChange(of: bookmarks.map(\.key)) { _, _ in reloadRows() }
        .onChange(of: packs.ids) { _, _ in reloadRows() }
        .onChange(of: selection.code(for: .prayers)) { _, _ in reloadRows() }
        .onChange(of: selection.code(for: .litanies)) { _, _ in reloadRows() }
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

    private func groupSection(_ group: SavedGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.title)
                .font(AppFont.title(size: 22))
                .foregroundStyle(palette.foreground.color)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                    savedRow(row)
                    if index < group.rows.count - 1 {
                        Rectangle()
                            .fill(palette.border.color)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private func reloadRows() {
        savedRows = SavedRows.rows(
            bookmarks,
            hymnLookup: { HymnImporter.record(id: $0, in: modelContext) },
            located: { bookmark in
                DevotionBookmarks.locate(
                    type: bookmark.type,
                    id: bookmark.itemId,
                    language: bookmark.language,
                    current: selection.openCode(forBookmarkType: bookmark.type),
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

    /// Removes the bookmark and offers Undo for a few seconds.
    private func remove(_ row: SavedRow) {
        guard let bookmark = bookmarks.first(where: { $0.key == row.id }) else { return }
        let removed = (draft: Bookmarks.draft(of: bookmark), language: bookmark.language)
        do {
            try Bookmarks.remove(type: row.type, id: row.itemId, in: modelContext)
        } catch {
            return
        }
        undo = RemovedBookmark(draft: removed.draft, language: removed.language, title: row.title)
        AccessibilityNotification.Announcement("Removed \(row.title). Undo is available.").post()
        undoTimer?.cancel()
        undoTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            undo = nil
        }
    }

    private func restoreRemoved() {
        guard let removed = undo else { return }
        undoTimer?.cancel()
        undo = nil
        try? Bookmarks.restore(removed.draft, language: removed.language, in: modelContext)
    }

    private func undoBar(_ removed: RemovedBookmark) -> some View {
        HStack(spacing: 12) {
            Text("Removed \(removed.title).")
                .font(AppFont.interface(size: 14))
                .foregroundStyle(palette.foreground.color)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: restoreRemoved) {
                Text("Undo")
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
                    .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityIdentifier("saved.undo")
        }
        .padding(.horizontal, 16)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.input.color, lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
    }

    private func removeButton(_ row: SavedRow) -> some View {
        Button {
            remove(row)
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
