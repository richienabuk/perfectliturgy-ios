import SwiftUI
import UIKit

struct StationsView: View {
    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    private let catalog = PackCatalogStore.shared
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.splitsColumns) private var splitsColumns

    @State private var showsLanguages = false
    @State private var openDownloads = false
    @State private var selectedOrder: Int?

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(.stations, requested: selection.code(for: .stations), installed: packs.languages(for: .stations), catalog: catalog.packs)
    }

    private var stations: [Station]? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .stations(_, let stations) = DevotionReader.load(.stations, language: language) else { return nil }
        return stations.isEmpty ? nil : stations
    }

    var body: some View {
        DevotionScreen(title: "Stations of the Cross") {
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
                title: DevotionKind.stations.languageTitle,
                languages: choice.languages,
                selected: choice.active,
                onSelect: { selection.select($0, for: .stations) },
                onDownload: { openDownloads = true }
            )
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DevotionHeading(title: "Stations of the Cross", support: DevotionKind.stations.support)
                languageButton
                if let stations {
                    ForEach(stations) { station in
                        DevotionListRow(
                            number: String(format: "%02d", station.order),
                            title: station.title,
                            subtitle: station.reference
                        ) {
                            open(station.order)
                        }
                    }
                    PLButton(title: "Begin the stations") {
                        open(stations.first?.order ?? 1)
                    }
                    .padding(.top, 8)
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
            if let order = activeOrder {
                StationView(order: order, showsChrome: false) { selectedOrder = $0 }
            } else {
                Text("Choose a station.")
                    .font(AppFont.body())
                    .foregroundStyle(palette.mutedForeground.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var activeOrder: Int? {
        guard let stations else { return nil }
        if let selectedOrder, stations.contains(where: { $0.order == selectedOrder }) {
            return selectedOrder
        }
        return stations.first?.order
    }

    private var languageButton: some View {
        LanguageButton(title: choice.buttonTitle, accessibilityLabel: "Stations language") {
            showsLanguages = true
        }
    }

    private func open(_ order: Int) {
        if splitsColumns {
            selectedOrder = order
        } else {
            navigation.path.append(AppRoute.station(order: order))
        }
    }

    private func openDownloadsIfNeeded() {
        guard openDownloads else { return }
        openDownloads = false
        navigation.path.append(AppRoute.downloads)
    }
}

struct StationView: View {
    let order: Int
    var showsChrome: Bool = true
    var onStep: ((Int) -> Void)? = nil

    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    private let catalog = PackCatalogStore.shared
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(.stations, requested: selection.code(for: .stations), installed: packs.languages(for: .stations), catalog: catalog.packs)
    }

    private var stations: [Station] {
        guard let language = choice.active, !choice.offersDownloads else { return [] }
        guard case .stations(_, let stations) = DevotionReader.load(.stations, language: language) else { return [] }
        return stations
    }

    private var station: Station? {
        stations.first { $0.order == order }
    }

    var body: some View {
        Group {
            if showsChrome {
                DevotionScreen(title: "Station") {
                    bodyContent
                }
            } else {
                bodyContent
            }
        }
        .accessibilityIdentifier("station.\(order)")
    }

    private var bodyContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let station {
                        stationBody(station)
                    } else {
                        DevotionMissingLanguage(message: choice.unavailableMessage) {
                            navigation.path.append(AppRoute.downloads)
                        }
                    }
                }
                .devotionColumn(isWide: isWide, maxWidth: 760)
            }
            if station != nil {
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.color)
    }

    private func stationBody(_ station: Station) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let image = StationArt.image(order: station.order) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 235)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .accessibilityLabel(station.title)
            }
            ReadingText(text: station.title, role: DevotionText.part)
            if let reference = station.reference, !reference.isEmpty {
                Text(reference)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("MEDITATION")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.mutedForeground.color)
                Text("A reflection, not a scripture quotation.")
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
                ReadingText(text: station.meditation, role: DevotionText.prayer)
            }
            PLCard(fill: .refrain) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LET US PRAY")
                        .font(AppFont.eyebrow())
                        .tracking(AppFont.eyebrowTracking)
                        .foregroundStyle(palette.primary.color)
                    ReadingText(text: station.prayer, role: DevotionText.response)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            PLButton(title: "Previous", kind: .outline, isEnabled: order > 1) {
                go(to: order - 1)
            }
            Text("Station \(order) of \(max(stations.count, order))")
                .font(AppFont.interface(size: 12, weight: .semibold))
                .foregroundStyle(palette.mutedForeground.color)
                .frame(minWidth: 88)
                .multilineTextAlignment(.center)
            PLButton(title: "Next", trailingSystemImage: "chevron.right", isEnabled: order < stations.count) {
                go(to: order + 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(palette.background.color)
    }

    private func go(to next: Int) {
        guard stations.contains(where: { $0.order == next }) else { return }
        if let onStep {
            onStep(next)
            return
        }
        guard showsChrome, !navigation.path.isEmpty else { return }
        navigation.path.removeLast()
        navigation.path.append(AppRoute.station(order: next))
    }
}

enum StationArt {
    static func image(order: Int, bundle: Bundle = .main) -> UIImage? {
        guard (1...14).contains(order) else { return nil }
        let name = String(format: "station-%02d", order)
        let folders = [nil, "Art", "Devotions/Art", "Stations"]
        for folder in folders {
            let url = if let folder {
                bundle.url(forResource: name, withExtension: "webp", subdirectory: folder)
            } else {
                bundle.url(forResource: name, withExtension: "webp")
            }
            if let url, let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}
