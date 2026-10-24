import SwiftUI

struct HymnFilterSheet: View {
    @Binding var season: String?
    @Binding var massPart: String?

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var sheetHeight: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            sheetTitle("Filter hymns")
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
            HStack(spacing: 12) {
                PLButton(title: "Clear all", kind: .outline) {
                    season = nil
                    massPart = nil
                }
                PLButton(title: "Show hymns", kind: .primary) {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.color)
        .fittedBottomSheet(height: $sheetHeight)
    }

    private func sheetTitle(_ title: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(AppFont.heading(size: 32))
                .foregroundStyle(palette.foreground.color)
                .tracking(32 * AppFont.headingTrackingFactor)
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close")
        }
    }

    private func filterGroup(
        title: String,
        codes: [String],
        selection: String?,
        name: @escaping (String) -> String,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
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

struct HymnLanguageSheet: View {
    var languages: [String]
    var selected: String?
    var onSelect: (String?) -> Void
    var onDownload: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var sheetHeight: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text("Each catalogue is one language.")
                .font(AppFont.interface(size: 16))
                .foregroundStyle(palette.mutedForeground.color)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 4) {
                choiceRow(title: "All languages", subtitle: nil, isSelected: selected == nil) {
                    onSelect(nil)
                }
                ForEach(languages, id: \.self) { code in
                    languageRow(code)
                }
                Button {
                    onDownload()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text("Download more languages")
                            .font(AppFont.interface(size: 17, weight: .semibold))
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(palette.foreground.color)
                    .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Download more languages")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.color)
        .fittedBottomSheet(height: $sheetHeight)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Hymn language")
                .font(AppFont.heading(size: 32))
                .foregroundStyle(palette.foreground.color)
                .tracking(32 * AppFont.headingTrackingFactor)
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func languageRow(_ code: String) -> some View {
        choiceRow(
            title: HymnLanguage.name(for: code),
            subtitle: HymnLanguage.catalogueName(for: code),
            isSelected: code == selected
        ) {
            onSelect(code)
        }
    }

    private func choiceRow(title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.interface(size: 17, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.interface(size: 15))
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primaryForeground.color)
                        .frame(width: 28, height: 28)
                        .background(palette.primary.color, in: Circle())
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func fittedBottomSheet(height: Binding<CGFloat>) -> some View {
        modifier(FittedBottomSheet(height: height))
    }
}

struct FittedBottomSheet: ViewModifier {
    @Binding var height: CGFloat
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SheetHeightKey.self,
                        value: proxy.size.height + proxy.safeAreaInsets.bottom
                    )
                }
            }
            .onPreferenceChange(SheetHeightKey.self) { newValue in
                guard newValue > 1, abs(height - newValue) > 1 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    height = newValue
                }
            }
            .presentationDetents([.height(max(height, 1))])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(palette.background.color)
    }
}
