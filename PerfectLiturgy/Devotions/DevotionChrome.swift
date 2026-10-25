import SwiftUI

struct DevotionScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.color)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct DevotionHeading: View {
    let title: String
    var support: String?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.heading(size: 40))
                .foregroundStyle(palette.foreground.color)
                .tracking(40 * AppFont.headingTrackingFactor)
                .accessibilityAddTraits(.isHeader)
            if let support {
                Text(support)
                    .font(AppFont.body())
                    .foregroundStyle(palette.mutedForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DevotionLanguageButton: View {
    let title: String
    var accessibilityLabel: String
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title)
    }
}

struct DevotionLanguageSheet: View {
    let kind: DevotionKind
    var languages: [String]
    var selected: String?
    var onSelect: (String) -> Void
    var onDownload: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text("Choose an installed language.")
                .font(AppFont.interface(size: 16))
                .foregroundStyle(palette.mutedForeground.color)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(languages, id: \.self) { code in
                    choiceRow(
                        title: HymnLanguage.name(for: code),
                        subtitle: "On this device",
                        isSelected: code == selected
                    ) {
                        onSelect(code)
                        dismiss()
                    }
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
        .fittedBottomSheet(key: "devotion.language.\(languages.count)", estimate: 320)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(kind.languageTitle)
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

    private func choiceRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.interface(size: 17, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    Text(subtitle)
                        .font(AppFont.interface(size: 15))
                        .foregroundStyle(palette.mutedForeground.color)
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

struct DevotionMissingLanguage: View {
    let message: String
    let openDownloads: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(message)
                .font(AppFont.body())
                .foregroundStyle(palette.foreground.color)
                .fixedSize(horizontal: false, vertical: true)
            PLButton(title: "Downloads", kind: .primary, action: openDownloads)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
    }
}

struct DevotionSearchField: View {
    let prompt: String
    @Binding var text: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.mutedForeground.color)
            TextField(prompt, text: $text)
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.foreground.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: ControlMetrics.minimumHeight)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(prompt)
    }
}

struct DevotionListRow: View {
    var number: String?
    let title: String
    var subtitle: String?
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                if let number {
                    Text(number)
                        .font(AppFont.title(size: 24))
                        .foregroundStyle(palette.emphasis.color)
                        .frame(width: 44, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .strokeBorder(palette.border.color, lineWidth: 1)
                        }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                        .multilineTextAlignment(.leading)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppFont.interface(size: 13))
                            .foregroundStyle(palette.mutedForeground.color)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.border.color)
                    .frame(height: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }
}

extension View {
    func devotionColumn(isWide: Bool, maxWidth: CGFloat = 720) -> some View {
        padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: isWide ? maxWidth : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

enum DevotionCopy {
    static func matches(_ query: String, haystack: String) -> Bool {
        let words = AccentFold.fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }
        let folded = AccentFold.fold(haystack)
        return words.allSatisfy { folded.contains($0) }
    }
}
