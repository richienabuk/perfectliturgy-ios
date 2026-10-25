import SwiftUI

struct OrderOfMassView: View {
    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    private let catalog = PackCatalogStore.shared
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    @State private var showsLanguages = false
    @State private var openDownloads = false

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(.order, requested: selection.code(for: .order), installed: packs.languages(for: .order), catalog: catalog.packs)
    }

    private var parts: [MassPart]? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .order(_, let parts) = DevotionReader.load(.order, language: language) else { return nil }
        return parts.isEmpty ? nil : parts
    }

    var body: some View {
        DevotionScreen(title: "Order of Mass") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DevotionHeading(title: "Order of Mass", support: DevotionKind.order.support)
                    languageButton
                    if let parts {
                        ForEach(parts) { part in
                            partSection(part)
                        }
                    } else {
                        DevotionMissingLanguage(message: choice.unavailableMessage) {
                            navigation.path.append(AppRoute.downloads)
                        }
                    }
                }
                .devotionColumn(isWide: isWide, maxWidth: 840)
            }
        }
        .sheet(isPresented: $showsLanguages, onDismiss: openDownloadsIfNeeded) {
            LanguageSheet(
                title: DevotionKind.order.languageTitle,
                languages: choice.languages,
                selected: choice.active,
                onSelect: { selection.select($0, for: .order) },
                onDownload: { openDownloads = true }
            )
        }
    }

    private var languageButton: some View {
        LanguageButton(title: choice.buttonTitle, accessibilityLabel: "Order of Mass language") {
            showsLanguages = true
        }
    }

    private func partSection(_ part: MassPart) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                ReadingText(text: part.title, role: DevotionText.part)
                if let summary = part.summary, !summary.isEmpty {
                    Text(summary)
                        .font(AppFont.interface(size: 15))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(part.items) { item in
                itemBlock(item)
            }
        }
    }

    private func itemBlock(_ item: MassItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ReadingText(text: item.title, role: DevotionText.item)
            if let rubric = item.rubric, !rubric.isEmpty {
                Text(rubric)
                    .font(AppFont.interface(size: 13, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let text = item.text, !text.isEmpty {
                ReadingText(text: text, role: DevotionText.prayer)
            }
            if let response = item.response, !response.isEmpty {
                PLCard(fill: .refrain) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RESPONSE")
                            .font(AppFont.eyebrow())
                            .tracking(AppFont.eyebrowTracking)
                            .foregroundStyle(palette.primary.color)
                        ReadingText(text: response, role: DevotionText.response)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func openDownloadsIfNeeded() {
        guard openDownloads else { return }
        openDownloads = false
        navigation.path.append(AppRoute.downloads)
    }
}
