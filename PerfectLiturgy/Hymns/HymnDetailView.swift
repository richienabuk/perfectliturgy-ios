import SwiftData
import SwiftUI

struct HymnDetailView: View {
    let id: String
    var showsChrome: Bool = true

    @Environment(\.palette) private var palette
    @Environment(\.readingScale) private var readingScale
    @Environment(\.modelContext) private var modelContext
    @Query private var hymns: [HymnRecord]
    @Query private var bookmarks: [HymnBookmark]

    private var hymn: HymnRecord? {
        hymns.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsChrome {
                PLTopBar()
            }
            if let hymn {
                detail(hymn)
            } else {
                missing
            }
        }
        .background(palette.background.color)
        .navigationTitle("Hymn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("hymn.\(id)")
        .task(id: hymn?.id) {
            guard let hymnID = hymn?.id else { return }
            try? HymnImporter.recordVisit(hymnID: hymnID, in: modelContext)
        }
    }

    private func detail(_ hymn: HymnRecord) -> some View {
        let saved = bookmarks.contains { $0.hymnId == hymn.id }
        let wide = !showsChrome
        let titleSize = max(readingScale.size(for: .partTitle), wide ? 40 : 34)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                            try? HymnImporter.toggleBookmark(hymn, in: modelContext)
                        }
                    }
                    HStack {
                        Text(HymnLanguage.catalogueName(for: hymn.language).uppercased())
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.emphasis.color)
                        Spacer(minLength: 8)
                        Text(lyricsStatus(hymn).uppercased())
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(String(hymn.hymnNumber))
                        .font(AppFont.title(size: max(36, 48 * CGFloat(readingScale.headings))))
                        .foregroundStyle(palette.emphasis.color)
                    if !wide {
                        Spacer(minLength: 8)
                        iconButton(systemName: saved ? "bookmark.fill" : "bookmark", label: saved ? "Remove saved hymn" : "Save hymn", filled: saved) {
                            try? HymnImporter.toggleBookmark(hymn, in: modelContext)
                        }
                        ShareLink(item: shareText(hymn)) {
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
                Text(hymn.title)
                    .font(AppFont.heading(size: titleSize))
                    .foregroundStyle(palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(wide ? wideMeta(hymn) : catalogueLine(hymn))
                    .font(AppFont.interface(size: 14))
                    .foregroundStyle(palette.mutedForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
                if !hymn.firstLine.isEmpty, !wide {
                    Text(hymn.firstLine)
                        .font(AppFont.interface(size: 15))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let details = performanceLine(hymn) {
                    Text(details)
                        .font(AppFont.interface(size: 14))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(blocks(hymn)) { block in
                    HymnSectionCard(block: block)
                }
                if wide {
                    ShareLink(item: shareText(hymn)) {
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

    private func lyricsStatus(_ hymn: HymnRecord) -> String {
        let hasMedia = !hymn.audioURLs.isEmpty || !hymn.videoURLs.isEmpty || !hymn.sheetMusicURLs.isEmpty
        return hasMedia ? "Lyrics · Recordings" : "Lyrics · No recordings"
    }

    private func wideMeta(_ hymn: HymnRecord) -> String {
        let meta = HymnLabels.detailMeta(seasons: hymn.seasons, massParts: hymn.massParts, topics: hymn.topics)
        return meta.isEmpty ? catalogueLine(hymn) : meta
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

    private func blocks(_ hymn: HymnRecord) -> [HymnLyricBlock] {
        HymnLyrics.blocks(sections: hymn.sectionTexts, lyrics: hymn.lyrics)
    }

    private func catalogueLine(_ hymn: HymnRecord) -> String {
        HymnLabels.catalogueLine(
            language: hymn.language,
            seasons: hymn.seasons,
            massParts: hymn.massParts,
            topics: hymn.topics
        )
    }

    private func performanceLine(_ hymn: HymnRecord) -> String? {
        var parts: [String] = []
        if let tune = hymn.tuneName, !tune.isEmpty { parts.append("Tune \(tune)") }
        if let key = hymn.musicalKey, !key.isEmpty { parts.append("Key \(key)") }
        if let authors = hymn.authors, !authors.isEmpty { parts.append(authors) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func shareText(_ hymn: HymnRecord) -> String {
        HymnShareText.make(
            language: hymn.language,
            number: hymn.hymnNumber,
            title: hymn.title,
            seasons: hymn.seasons,
            massParts: hymn.massParts,
            topics: hymn.topics,
            sections: hymn.sectionTexts,
            lyrics: hymn.lyrics,
            tuneName: hymn.tuneName,
            musicalKey: hymn.musicalKey
        )
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
