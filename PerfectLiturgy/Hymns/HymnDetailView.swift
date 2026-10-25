import SwiftData
import SwiftUI

struct HymnDetailView: View {
    let id: String
    var showsChrome: Bool = true

    /// Pass a page already read from the store, so the first frame has the hymn on it.
    /// Without one the screen reads it after it appears.
    init(id: String, showsChrome: Bool = true, initialPage: HymnPage? = nil) {
        self.id = id
        self.showsChrome = showsChrome
        _page = State(initialValue: initialPage)
    }

    @Environment(\.palette) private var palette
    @Environment(\.readingScale) private var readingScale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @State private var page: HymnPage?
    private let packStore = PackCatalogStore.shared
    @Query private var bookmarks: [HymnBookmark]

    var body: some View {
        VStack(spacing: 0) {
            if showsChrome, !isWide || page == nil {
                PLTopBar()
            }
            if let page {
                detail(page)
            } else {
                missing
            }
        }
        .background(palette.background.color)
        .navigationTitle("Hymn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("hymn.\(id)")
        .onReceive(NotificationCenter.default.publisher(for: .hymnStoreDidChange)) { _ in
            loadPage()
        }
        .task(id: id) {
            if page?.id != id {
                loadPage()
            }
            guard page != nil else { return }
            recordVisitAfterTransition()
        }
    }

    private func loadPage() {
        page = HymnImporter.page(id: id, in: modelContext)
    }

    /// Saving the visit writes to disk. It waits for the push to finish, and it is not
    /// cancelled if the reader goes back first: the hymn was opened.
    private func recordVisitAfterTransition() {
        let hymnID = id
        let context = modelContext
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            try? HymnImporter.recordVisit(hymnID: hymnID, in: context)
        }
    }

    private func catalogueName(for hymn: HymnPage) -> String {
        HymnLanguage.catalogueName(for: hymn.language, in: packStore.packs)
    }

    private func catalogueLine(_ hymn: HymnPage) -> String {
        let plain = HymnLanguage.catalogueName(for: hymn.language)
        let named = catalogueName(for: hymn)
        guard hymn.catalogueLine.hasPrefix(plain) else { return hymn.catalogueLine }
        return named + hymn.catalogueLine.dropFirst(plain.count)
    }

    private func detail(_ hymn: HymnPage) -> some View {
        let saved = bookmarks.contains { $0.hymnId == hymn.id }
        let wide = !showsChrome
        let tablet = isWide && showsChrome
        let titleSize = max(readingScale.size(for: .partTitle), wide ? 40 : 34)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if tablet {
                    HStack(spacing: 8) {
                        backButton
                        Spacer(minLength: 8)
                        hymnActions(hymn, saved: saved)
                    }
                }
                if wide {
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Text("LIBRARY")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                            Text("HYMNS")
                        }
                        .font(AppFont.eyebrow())
                        .tracking(AppFont.eyebrowTracking)
                        .foregroundStyle(palette.mutedForeground.color)
                        Spacer(minLength: 8)
                        iconButton(systemName: saved ? "bookmark.fill" : "bookmark", label: saved ? "Remove saved hymn" : "Save hymn", filled: saved) {
                            toggleSaved()
                        }
                    }
                    HStack {
                        Text(catalogueName(for: hymn).uppercased())
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.emphasis.color)
                        Spacer(minLength: 8)
                        Text(hymn.lyricsStatus.uppercased())
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(String(hymn.hymnNumber))
                        .font(AppFont.title(size: max(36, 48 * CGFloat(readingScale.headings))))
                        .foregroundStyle(palette.emphasis.color)
                    if !wide, !tablet {
                        Spacer(minLength: 8)
                        hymnActions(hymn, saved: saved)
                    }
                }
                Text(hymn.title)
                    .font(AppFont.heading(size: titleSize))
                    .foregroundStyle(palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(wide ? hymn.wideMeta : catalogueLine(hymn))
                    .font(AppFont.interface(size: 14))
                    .foregroundStyle(palette.mutedForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
                if !hymn.firstLine.isEmpty, !wide {
                    Text(hymn.firstLine)
                        .font(AppFont.interface(size: 15))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let details = hymn.performanceLine {
                    Text(details)
                        .font(AppFont.interface(size: 14))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(hymn.blocks) { block in
                    HymnSectionCard(block: block)
                }
                if wide {
                    ShareLink(item: hymn.shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(AppFont.interface(size: 14, weight: .semibold))
                            .foregroundStyle(palette.foreground.color)
                            .frame(minHeight: ControlMetrics.minimumHeight)
                    }
                    .accessibilityLabel("Share hymn")
                }
                if let notes = hymn.backgroundNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATALOGUE NOTE")
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.mutedForeground.color)
                        ReadingText(text: notes, role: .prayer)
                    }
                }
                HymnMediaSection(
                    audioURLs: hymn.audioURLs,
                    videoURLs: hymn.videoURLs,
                    sheetMusicURLs: hymn.sheetMusicURLs
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, wide ? 28 : 20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.foreground.color)
                .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
                .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(palette.border.color, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Back")
    }

    private func hymnActions(_ hymn: HymnPage, saved: Bool) -> some View {
        HStack(spacing: 8) {
            iconButton(systemName: saved ? "bookmark.fill" : "bookmark", label: saved ? "Remove saved hymn" : "Save hymn", filled: saved) {
                toggleSaved()
            }
            ShareLink(item: hymn.shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.foreground.color)
                    .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
                    .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(palette.border.color, lineWidth: 1)
                    }
            }
            .accessibilityLabel("Share hymn")
        }
    }

    private func iconButton(systemName: String, label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundStyle(filled ? palette.emphasis.color : palette.foreground.color)
                .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
                .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(palette.border.color, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func toggleSaved() {
        guard let hymn = HymnImporter.record(id: id, in: modelContext) else { return }
        try? HymnImporter.toggleBookmark(hymn, in: modelContext)
    }

    private var missing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hymn unavailable")
                .font(AppFont.heading(size: 32))
                .foregroundStyle(palette.foreground.color)
            Text("This hymn could not be opened from the local catalogue.")
                .font(AppFont.body())
                .foregroundStyle(palette.mutedForeground.color)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A stanza or refrain card with a colour rule on the leading edge.
struct HymnSectionCard: View {
    var block: HymnLyricBlock

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(block.heading)
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.mutedForeground.color)
            ReadingText(text: block.content, role: .response)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            Rectangle()
                .fill(block.card == .refrain ? palette.liturgicalBackground.color : palette.emphasis.color)
                .frame(width: 4)
        }
        .background(block.card == .refrain ? palette.refrain.color : palette.stanza.color)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
    }
}
