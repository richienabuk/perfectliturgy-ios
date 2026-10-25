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
