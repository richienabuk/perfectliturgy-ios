import SwiftUI

struct PrayersView: View {
    @Environment(InstalledPacks.self) private var packs
    @Environment(DevotionSession.self) private var session
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.splitsColumns) private var splitsColumns

    @State private var showsLanguages = false
    @State private var openDownloads = false
    @State private var query = ""
    @State private var selectedID: String?

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(requested: session.code(for: .prayers), installed: packs.languages(for: .prayers))
    }

    private var prayers: [SpecialPrayer]? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .prayers(_, let prayers) = DevotionReader.load(.prayers, language: language) else { return nil }
        return prayers.isEmpty ? nil : prayers
    }

    private var groups: [(category: String, prayers: [SpecialPrayer])] {
        guard let prayers else { return [] }
        let matched = prayers.filter { prayer in
            DevotionCopy.matches(query, haystack: "\(prayer.title) \(prayer.summary ?? "") \(prayer.category ?? "") \(prayer.text)")
        }
        var names: [String] = []
        var buckets: [String: [SpecialPrayer]] = [:]
        for prayer in matched {
            let name = prayer.category.flatMap { $0.isEmpty ? nil : $0 } ?? "Prayers"
            if buckets[name] == nil {
                names.append(name)
            }
            buckets[name, default: []].append(prayer)
        }
        return names.map { (category: $0, prayers: buckets[$0] ?? []) }
    }

    var body: some View {
        DevotionScreen(title: "Special Prayers") {
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
            DevotionLanguageSheet(
                kind: .prayers,
                languages: packs.languages(for: .prayers),
                selected: choice.active,
                onSelect: { session.select($0, for: .prayers) },
                onDownload: { openDownloads = true }
            )
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DevotionHeading(title: "Special Prayers", support: DevotionKind.prayers.support)
                languageButton
                if prayers != nil {
                    DevotionSearchField(prompt: "Find a prayer", text: $query)
                    if groups.isEmpty {
                        Text("No prayers match.")
                            .font(AppFont.body())
                            .foregroundStyle(palette.mutedForeground.color)
                    } else {
                        ForEach(groups, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.category.uppercased())
                                    .font(AppFont.eyebrow())
                                    .tracking(AppFont.eyebrowTracking)
                                    .foregroundStyle(palette.mutedForeground.color)
                                    .padding(.top, 8)
                                ForEach(group.prayers) { prayer in
                                    DevotionListRow(title: prayer.title, subtitle: prayer.summary) {
                                        open(prayer.id)
                                    }
                                }
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
                PrayerView(id: id, showsChrome: false)
            } else {
                Text("Choose a prayer.")
                    .font(AppFont.body())
                    .foregroundStyle(palette.mutedForeground.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var activeID: String? {
        let visible = groups.flatMap(\.prayers)
        if let selectedID, visible.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return visible.first?.id
    }

    private var languageButton: some View {
        DevotionLanguageButton(title: choice.buttonTitle, accessibilityLabel: "Prayers language") {
            showsLanguages = true
        }
    }

    private func open(_ id: String) {
        if splitsColumns {
            selectedID = id
        } else {
            navigation.path.append(AppRoute.prayer(id: id))
        }
    }

    private func openDownloadsIfNeeded() {
        guard openDownloads else { return }
        openDownloads = false
        navigation.path.append(AppRoute.downloads)
    }
}

struct PrayerView: View {
    let id: String
    var showsChrome: Bool = true

    @Environment(InstalledPacks.self) private var packs
    @Environment(DevotionSession.self) private var session
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    @State private var showsLanguages = false
    @State private var openDownloads = false

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(requested: session.code(for: .prayers), installed: packs.languages(for: .prayers))
    }

    private var prayer: SpecialPrayer? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .prayers(_, let prayers) = DevotionReader.load(.prayers, language: language) else { return nil }
        return prayers.first { $0.id == id }
    }

    var body: some View {
        Group {
            if showsChrome {
                DevotionScreen(title: "Prayer") { bodyContent }
            } else {
                bodyContent
            }
        }
        .accessibilityIdentifier("prayer.\(id)")
        .sheet(isPresented: $showsLanguages, onDismiss: openDownloadsIfNeeded) {
            DevotionLanguageSheet(
                kind: .prayers,
                languages: packs.languages(for: .prayers),
                selected: choice.active,
                onSelect: { session.select($0, for: .prayers) },
                onDownload: { openDownloads = true }
            )
        }
    }

    private var bodyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                languageButton
                if let prayer {
                    prayerBody(prayer)
                } else {
                    DevotionMissingLanguage(message: choice.unavailableMessage) {
                        navigation.path.append(AppRoute.downloads)
                    }
                }
            }
            .devotionColumn(isWide: isWide, maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.color)
    }

    private var languageButton: some View {
        DevotionLanguageButton(title: choice.buttonTitle, accessibilityLabel: "Prayers language") {
            showsLanguages = true
        }
    }

    private func prayerBody(_ prayer: SpecialPrayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ReadingText(text: prayer.title, role: DevotionText.part)
            if let summary = prayer.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppFont.interface(size: 15))
                    .foregroundStyle(palette.mutedForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ReadingText(text: prayer.text, role: DevotionText.prayer)
        }
    }

    private func openDownloadsIfNeeded() {
        guard openDownloads else { return }
        openDownloads = false
        navigation.path.append(AppRoute.downloads)
    }
}
