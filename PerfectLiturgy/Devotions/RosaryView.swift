import SwiftUI

struct RosaryView: View {
    @Environment(InstalledPacks.self) private var packs
    @Environment(LanguageSelection.self) private var selection
    private let catalog = PackCatalogStore.shared
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showsLanguages = false
    @State private var showsMysteries = false
    @State private var openDownloads = false
    @State private var mysteryID: String?
    @State private var stepIndex = 0

    private var choice: DevotionLanguageChoice {
        DevotionLanguageChoice(.rosary, requested: selection.code(for: .rosary), installed: packs.languages(for: .rosary), catalog: catalog.packs)
    }

    private var pack: RosaryPack? {
        guard let language = choice.active, !choice.offersDownloads else { return nil }
        guard case .rosary(_, let pack) = DevotionReader.load(.rosary, language: language) else { return nil }
        return pack.mysteries.isEmpty ? nil : pack
    }

    private var mystery: RosaryMysterySet? {
        guard let pack else { return nil }
        if let mysteryID, let match = pack.mysteries.first(where: { $0.id == mysteryID }) {
            return match
        }
        let suggested = RosaryGuide.suggestedID()
        return pack.mysteries.first { $0.id == suggested } ?? pack.mysteries.first
    }

    private var steps: [RosaryStep] {
        guard let pack, let mystery else { return [] }
        return RosaryGuide.steps(prayers: pack.prayers, set: mystery)
    }

    private var step: RosaryStep? {
        guard !steps.isEmpty else { return nil }
        return steps[min(stepIndex, steps.count - 1)]
    }

    /// Tablet and landscape share one control line so the prayer stays on screen.
    private var usesSingleRow: Bool {
        isWide || verticalSizeClass == .compact
    }

    var body: some View {
        DevotionScreen(title: "Holy Rosary") {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            controls
                            if showsMysteries, let pack, let mystery {
                                mysteryPicker(pack: pack, selected: mystery)
                            }
                            if let mystery, let step {
                                reader(mystery: mystery, step: step)
                            } else {
                                DevotionMissingLanguage(message: choice.unavailableMessage) {
                                    navigation.path.append(AppRoute.downloads)
                                }
                            }
                        }
                        .devotionColumn(isWide: isWide)
                    }
                    .onChange(of: stepIndex) { _, _ in
                        proxy.scrollTo("rosary-focus", anchor: .top)
                    }
                }
                if step != nil {
                    footer
                }
            }
        }
        .sheet(isPresented: $showsLanguages, onDismiss: openDownloadsIfNeeded) {
            LanguageSheet(
                title: DevotionKind.rosary.languageTitle,
                languages: choice.languages,
                selected: choice.active,
                onSelect: { code in
                    selection.select(code, for: .rosary)
                    stepIndex = 0
                },
                onDownload: { openDownloads = true }
            )
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !usesSingleRow {
                screenTitle
            }
            HStack(alignment: .center, spacing: 8) {
                if usesSingleRow {
                    screenTitle
                    Spacer(minLength: 8)
                }
                languageButton
                if mystery != nil {
                    if !usesSingleRow {
                        Spacer(minLength: 8)
                    }
                    mysteryToggle
                }
            }
        }
    }

    private var screenTitle: some View {
        Text("Holy Rosary")
            .font(AppFont.heading(size: usesSingleRow ? 28 : 36))
            .foregroundStyle(palette.foreground.color)
            .tracking((usesSingleRow ? 28 : 36) * AppFont.headingTrackingFactor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityAddTraits(.isHeader)
    }

    private var languageButton: some View {
        LanguageButton(title: choice.buttonTitle, accessibilityLabel: "Rosary language", fillsWidth: false) {
            showsLanguages = true
        }
    }

    private var mysteryToggle: some View {
        Button {
            showsMysteries.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(mystery?.title ?? "Mysteries")
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: showsMysteries ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
            }
            .foregroundStyle(palette.foreground.color)
            .padding(.horizontal, 14)
            .frame(minHeight: ControlMetrics.minimumHeight)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(showsMysteries ? palette.primary.color : palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Choose today's mysteries")
        .accessibilityValue(mystery?.title ?? "")
        .accessibilityAddTraits(showsMysteries ? .isSelected : [])
    }

    private func mysteryPicker(pack: RosaryPack, selected: RosaryMysterySet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(pack.mysteries) { set in
                    mysteryChip(set, selected: set.id == selected.id)
                }
            }
            if let days = selected.days, !days.isEmpty {
                Text(days)
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
                    .accessibilityLabel("Suggested days, \(days)")
            }
        }
    }

    private func reader(mystery: RosaryMysterySet, step: RosaryStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if isWide, step.beads != nil {
                HStack(alignment: .top, spacing: 16) {
                    prayerColumn(mystery: mystery, step: step)
                    if let focus = step.beads, let label = step.beadLabel, let decade = step.decade {
                        beadCard(decade: decade, count: mystery.titles.count, focus: focus, label: label)
                            .frame(maxWidth: 280)
                    }
                }
            } else {
                prayerColumn(mystery: mystery, step: step)
                if let focus = step.beads, let label = step.beadLabel, let decade = step.decade {
                    beadCard(decade: decade, count: mystery.titles.count, focus: focus, label: label)
                }
            }
        }
    }

    private func prayerColumn(mystery: RosaryMysterySet, step: RosaryStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            contextBanner(mystery: mystery, step: step)
            prayerCard(step)
            progress(step)
        }
    }

    private func mysteryChip(_ set: RosaryMysterySet, selected: Bool) -> some View {
        Button {
            mysteryID = set.id
            stepIndex = 0
            showsMysteries = false
        } label: {
            Text(set.title)
                .font(AppFont.interface(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(selected ? palette.primaryForeground.color : palette.foreground.color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ControlMetrics.minimumHeight)
                .padding(.horizontal, 4)
                .background(selected ? palette.primary.color : palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(selected ? palette.primary.color : palette.border.color, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(set.days.map { "\(set.title), \($0)" } ?? set.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func contextBanner(mystery: RosaryMysterySet, step: RosaryStep) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(bannerLead(mystery: mystery, step: step))
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.emphasis.color)
            Spacer(minLength: 8)
            Text(bannerTrail(mystery: mystery, step: step))
                .font(AppFont.interface(size: 14, weight: .semibold))
                .foregroundStyle(palette.foreground.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight)
        .background(palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .id("rosary-focus")
    }

    private func bannerLead(mystery: RosaryMysterySet, step: RosaryStep) -> String {
        if let decade = step.decade {
            return "MYSTERY \(decade + 1) OF \(mystery.titles.count)"
        }
        return "\(mystery.title.uppercased()) MYSTERIES"
    }

    private func bannerTrail(mystery: RosaryMysterySet, step: RosaryStep) -> String {
        if let title = step.mysteryTitle, step.decade != nil {
            return title
        }
        return "Opening and concluding prayers"
    }

    private func beadCard(decade: Int, count: Int, focus: RosaryBeadFocus, label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DECADE \(decade + 1) OF \(count)")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.mutedForeground.color)
                Spacer(minLength: 8)
                Text(label)
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.emphasis.color)
                    .multilineTextAlignment(.trailing)
            }
            BeadRing(focus: focus)
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(palette.emphasis.color)
                        .frame(width: 8, height: 8)
                    Text("Current Hail Mary")
                }
                Spacer(minLength: 8)
                Text("Follow clockwise, 1 to 10")
            }
            .font(AppFont.interface(size: 11))
            .foregroundStyle(palette.mutedForeground.color)
        }
        .padding(14)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
    }

    private func progress(_ step: RosaryStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STEP \(step.index + 1) OF \(steps.count)")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.mutedForeground.color)
                Spacer(minLength: 8)
                Text(step.kindLabel)
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.mutedForeground.color)
            }
            GeometryReader { proxy in
                let fraction = steps.isEmpty ? 0 : CGFloat(step.index + 1) / CGFloat(steps.count)
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.border.color)
                    Capsule()
                        .fill(palette.primary.color)
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 3)
            .accessibilityLabel("Step \(step.index + 1) of \(steps.count)")
        }
    }

    private func prayerCard(_ step: RosaryStep) -> some View {
        PLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(step.cue)
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.emphasis.color)
                ReadingText(text: step.title, role: DevotionText.item)
                    .accessibilityIdentifier("rosary.step")
                ReadingText(text: step.text, role: DevotionText.prayer)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            PLButton(title: "Previous", kind: .outline, isEnabled: stepIndex > 0) {
                stepIndex = max(0, stepIndex - 1)
            }
            PLButton(
                title: stepIndex >= steps.count - 1 ? "Pray again" : "Next prayer",
                trailingSystemImage: stepIndex >= steps.count - 1 ? nil : "chevron.right"
            ) {
                if stepIndex >= steps.count - 1 {
                    stepIndex = 0
                } else {
                    stepIndex += 1
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(palette.background.color)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.border.color)
                .frame(height: 1)
        }
    }

    private func openDownloadsIfNeeded() {
        guard openDownloads else { return }
        openDownloads = false
        navigation.path.append(AppRoute.downloads)
    }
}

private struct BeadRing: View {
    let focus: RosaryBeadFocus

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.border.color, lineWidth: 1)
                .frame(width: 148, height: 148)
            ForEach(1...10, id: \.self) { number in
                bead(number)
                    .position(point(number))
            }
        }
        .frame(width: 220, height: 200)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch focus {
        case .waiting: "Decade not yet on a Hail Mary"
        case .hailMary(let number): "Hail Mary bead \(number) of ten"
        case .complete: "Decade complete"
        }
    }

    private func bead(_ number: Int) -> some View {
        let style = style(for: number)
        return Text("\(number)")
            .font(AppFont.interface(size: style == .current ? 13 : 12, weight: .semibold))
            .foregroundStyle(style == .upcoming ? palette.primary.color : palette.primaryForeground.color)
            .frame(width: style == .current ? 32 : 28, height: style == .current ? 32 : 28)
            .background(fill(style), in: Circle())
            .overlay {
                Circle().strokeBorder(palette.primary.color, lineWidth: style == .upcoming ? 1.5 : 0)
            }
    }

    private func point(_ number: Int) -> CGPoint {
        let angle = (-Double.pi / 2) + (Double(number - 1) * 2 * Double.pi / 10)
        let radius = 74.0
        return CGPoint(
            x: 110 + radius * cos(angle),
            y: 100 + radius * sin(angle)
        )
    }

    private enum BeadStyle {
        case done
        case current
        case upcoming
    }

    private func style(for number: Int) -> BeadStyle {
        switch focus {
        case .waiting:
            .upcoming
        case .complete:
            .done
        case .hailMary(let current):
            if number < current { .done }
            else if number == current { .current }
            else { .upcoming }
        }
    }

    private func fill(_ style: BeadStyle) -> Color {
        switch style {
        case .done: palette.primary.color
        case .current: palette.emphasis.color
        case .upcoming: palette.card.color
        }
    }
}
