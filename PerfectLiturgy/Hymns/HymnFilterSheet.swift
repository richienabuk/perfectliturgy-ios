import SwiftUI

struct HymnFilterSheet: View {
    @Binding var language: String?
    @Binding var season: String?
    @Binding var massPart: String?
    var languages: [String]
    var matchCount: Int

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(HymnLabels.matchCount(matchCount))
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    filterGroup(title: "Language", codes: languages, selection: language) { code in
                        HymnLanguage.name(for: code)
                    } toggle: { code in
                        language = language == code ? nil : code
                    }
                    filterGroup(title: "Season", codes: HymnFilter.seasons, selection: season) { code in
                        HymnLabels.token(code)
                    } toggle: { code in
                        season = season == code ? nil : code
                    }
                    filterGroup(title: "Part of Mass", codes: HymnFilter.massParts, selection: massPart) { code in
                        HymnLabels.token(code)
                    } toggle: { code in
                        massPart = massPart == code ? nil : code
                    }
                    Button("Clear all") {
                        language = nil
                        season = nil
                        massPart = nil
                    }
                    .buttonStyle(.plain)
                    .font(AppFont.interface(size: 16, weight: .semibold))
                    .foregroundStyle(palette.primary.color)
                    .frame(minHeight: ControlMetrics.minimumHeight)
                    .accessibilityLabel("Clear all")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.background.color)
            .navigationTitle("Filter hymns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.primary.color)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(palette.background.color)
    }

    private func filterGroup(
        title: String,
        codes: [String],
        selection: String?,
        name: @escaping (String) -> String,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.interface(size: 14, weight: .semibold))
                .foregroundStyle(palette.mutedForeground.color)
            FlexibleChips(codes: codes, selection: selection, name: name, toggle: toggle)
        }
    }
}

private struct FlexibleChips: View {
    var codes: [String]
    var selection: String?
    var name: (String) -> String
    var toggle: (String) -> Void

    var body: some View {
        HymnChipFlow(spacing: 8) {
            ForEach(codes, id: \.self) { code in
                chip(code)
            }
        }
    }

    private func chip(_ code: String) -> some View {
        let selected = selection == code
        return Button {
            toggle(code)
        } label: {
            Text(name(code))
                .font(AppFont.interface(size: 14, weight: .semibold))
                .foregroundStyle(selected ? paletteForeground : paletteInk)
                .padding(.horizontal, 12)
                .frame(minHeight: ControlMetrics.minimumHeight)
                .background(selected ? palettePrimary : paletteCard, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(selected ? palettePrimary : paletteBorder, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @Environment(\.palette) private var palette
    private var paletteForeground: Color { palette.primaryForeground.color }
    private var paletteInk: Color { palette.foreground.color }
    private var palettePrimary: Color { palette.primary.color }
    private var paletteCard: Color { palette.card.color }
    private var paletteBorder: Color { palette.border.color }
}

/// A simple wrapping row for filter chips. Width comes from the parent.
private struct HymnChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rows(width: width, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indexes {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.indexes.append(index)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.indexes.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct Row {
        var indexes: [Int] = []
        var height: CGFloat = 0
    }
}
