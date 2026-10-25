import SwiftData
import SwiftUI

struct LitaniesView: View {
    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    private let catalog = PackCatalogStore.shared
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.splitsColumns) private var splitsColumns

    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [Bookmark]

    @State private var showsLanguages = false
    @State private var openDownloads = false
    @State private var query = ""
    @State private var selectedID: String?

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(.litanies, requested: selection.code(for: .litanies), installed: packs.languages(for: .litanies), catalog: catalog.packs)
    }

    private var litanies: [Litany]? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .litanies(_, let litanies) = DevotionReader.load(.litanies, language: language) else { return nil }
        return litanies.isEmpty ? nil : litanies
    }

    private var filtered: [Litany] {
        guard let litanies else { return [] }
        return litanies.filter { litany in
            let haystack = [litany.title, litany.summary, litany.category]
                .compactMap { $0 }
                .joined(separator: " ")
            return DevotionCopy.matches(query, haystack: haystack)
        }
    }

    var body: some View {
        DevotionScreen(title: "Litanies") {
            Group {
                if splitsColumns {
                    HStack(spacing: 0) {
                        list.frame(maxWidth: 440)
                        Rectangle().fill(palette.border.color).frame(width: 1)
                        detailColumn
                    }
                } else {
                    list
                }
            }
        }
        .sheet(isPresented: $showsLanguages, onDismiss: openDownloadsIfNeeded) {
            LanguageSheet(
                title: DevotionKind.litanies.languageTitle,
                languages: choice.languages,
                selected: choice.active,
                onSelect: { selection.select($0, for: .litanies) },
                onDownload: { openDownloads = true }
            )
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DevotionHeading(title: "Litanies", support: DevotionKind.litanies.support)
                languageButton
                if litanies != nil {
                    DevotionSearchField(prompt: "Find a litany", text: $query)
                    HStack {
                        Text((filtered.first?.category ?? "Litanies").uppercased())
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.mutedForeground.color)
                        Spacer(minLength: 8)
                        Text("\(filtered.count)")
                            .font(AppFont.interface(size: 13))
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                    if filtered.isEmpty {
                        Text("No litanies match.")
                            .font(AppFont.body())
                            .foregroundStyle(palette.mutedForeground.color)
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, litany in
                            DevotionListRow(
                                number: String(format: "%02d", index + 1),
                                title: litany.title,
                                subtitle: litany.summary,
                                saved: isSaved(litany.id),
                                saveLabel: "Save litany",
                                removeLabel: "Remove saved litany",
                                saveIdentifier: "litany.row.save.\(litany.id)",
                                onToggleSaved: { toggle(litany) }
                            ) {
                                open(litany.id)
                            }
                        }
                    }
                } else {
                    DevotionMissingLanguage(message: choice.unavailableMessage) {
                        navigation.path.append(AppRoute.downloads)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var detailColumn: some View {
        Group {
            if let id = activeID {
                LitanyView(id: id, showsChrome: false)
            } else {
                Text("Choose a litany.")
                    .font(AppFont.body())
                    .foregroundStyle(palette.mutedForeground.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var activeID: String? {
        if let selectedID, filtered.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return filtered.first?.id
    }

    private var languageButton: some View {
        LanguageButton(title: choice.buttonTitle, accessibilityLabel: "Litanies language") {
            showsLanguages = true
        }
    }

    private func isSaved(_ id: String) -> Bool {
        saved.contains { $0.type == BookmarkType.litanies && $0.itemId == id }
    }

    private func toggle(_ litany: Litany) {
        guard let language = choice.active else { return }
        try? Bookmarks.toggle(
            type: BookmarkType.litanies,
            id: litany.id,
            title: litany.title,
            language: language,
            in: modelContext
        )
    }

    private func open(_ id: String) {
        if splitsColumns {
            selectedID = id
        } else {
            navigation.path.append(AppRoute.litany(id: id))
        }
    }

    private func openDownloadsIfNeeded() {
        guard openDownloads else { return }
        openDownloads = false
        navigation.path.append(AppRoute.downloads)
    }
}

struct LitanyView: View {
    let id: String
    var showsChrome: Bool = true

    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    private let catalog = PackCatalogStore.shared
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [Bookmark]

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(.litanies, requested: selection.code(for: .litanies), installed: packs.languages(for: .litanies), catalog: catalog.packs)
    }

    private var litany: Litany? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .litanies(_, let litanies) = DevotionReader.load(.litanies, language: language) else { return nil }
        return litanies.first { $0.id == id }
    }

    var body: some View {
        Group {
            if showsChrome {
                DevotionScreen(title: "Litany") { bodyContent }
            } else {
                bodyContent
            }
        }
        .accessibilityIdentifier("litany.\(id)")
    }

    private var bodyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let litany {
                    litanyBody(litany)
                } else {
                    DevotionMissingLanguage(message: choice.unavailableMessage) {
                        navigation.path.append(AppRoute.downloads)
                    }
                }
            }
            .devotionColumn(isWide: isWide, maxWidth: 840)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.color)
    }

    private func litanyBody(_ litany: Litany) -> some View {
        let isSaved = saved.contains { $0.type == BookmarkType.litanies && $0.itemId == litany.id }
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    ReadingText(text: litany.title, role: DevotionText.part)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SaveMark(
                        saved: isSaved,
                        saveLabel: "Save litany",
                        removeLabel: "Remove saved litany",
                        identifier: "litany.save.\(litany.id)"
                    ) {
                        guard let language = choice.active else { return }
                        try? Bookmarks.toggle(
                            type: BookmarkType.litanies,
                            id: litany.id,
                            title: litany.title,
                            language: language,
                            in: modelContext
                        )
                    }
                }
                if let summary = litany.summary, !summary.isEmpty {
                    Text(summary)
                        .font(AppFont.interface(size: 15))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("FULL TEXT · CALL AND RESPONSE")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.emphasis.color)
                PLCard {
                    VStack(spacing: 0) {
                        ForEach(litany.lines) { line in
                            lineRow(line)
                        }
                    }
                }
            }
        }
    }

    private func lineRow(_ line: LitanyLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ReadingText(text: line.call, role: DevotionText.prayer)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let response = line.response, !response.isEmpty {
                ReadingText(text: response, role: DevotionText.response, tint: palette.primary.color)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border.color)
                .frame(height: 1)
        }
    }
}
