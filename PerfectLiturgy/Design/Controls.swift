import SwiftUI
import UIKit

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .scaleEffect(pressed ? ControlMetrics.pressScale : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: ControlMetrics.pressDuration),
                value: configuration.isPressed
            )
    }
}

struct PLButton: View {
    enum Kind {
        case primary
        case secondary
        case outline
    }

    let title: String
    var kind: Kind = .primary
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.interface(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ControlMetrics.minimumHeight)
                .padding(.horizontal, 16)
                .background(background, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay {
                    if kind == .outline {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(palette.border.color, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var background: Color {
        switch kind {
        case .primary: palette.primary.color
        case .secondary: palette.secondary.color
        case .outline: .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: palette.primaryForeground.color
        case .secondary: palette.secondaryForeground.color
        case .outline: palette.primary.color
        }
    }
}

struct PLChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.interface(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? palette.primaryForeground.color : palette.foreground.color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ControlMetrics.minimumHeight)
                .padding(.horizontal, 12)
                .background(isSelected ? palette.primary.color : palette.card.color, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(isSelected ? palette.primary.color : palette.border.color, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PLHeading: View {
    let lead: String
    var emphasis: String?
    var size: CGFloat = 36

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lead)
                .font(AppFont.heading(size: size))
                .foregroundStyle(palette.foreground.color)
            if let emphasis {
                Text(emphasis)
                    .font(AppFont.heading(size: size, italic: true))
                    .foregroundStyle(palette.emphasis.color)
            }
        }
        .tracking(size * AppFont.headingTrackingFactor)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct PLEyebrow: View {
    let text: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(palette.emphasis.color)
                .frame(width: 16, height: 1)
            Text(text.uppercased())
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.mutedForeground.color)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PLCard<Content: View>: View {
    var fill: CardFill = .card
    @ViewBuilder var content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
    }

    private var color: Color {
        switch fill {
        case .card: palette.card.color
        case .stanza: palette.stanza.color
        case .refrain: palette.refrain.color
        }
    }
}

enum CardFill {
    case card
    case stanza
    case refrain
}

struct LiturgicalBanner: View {
    let title: String
    var detail: String?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.title(size: 26))
                .foregroundStyle(palette.liturgicalForeground.color)
            if let detail {
                Text(detail)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.liturgicalAccent.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.liturgicalBackground.color, in: RoundedRectangle(cornerRadius: Radius.lg))
    }
}

struct ReadingText: View {
    let text: String
    var role: ReadingRole

    @Environment(\.palette) private var palette
    @Environment(\.readingScale) private var readingScale

    var body: some View {
        let size = readingScale.size(for: role)
        Text(text)
            .font(font(size: size))
            .foregroundStyle(palette.foreground.color)
            .lineSpacing(extraLeading(size: size))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Extra space so the line height matches the role. Headings stay tight. Prayer and response use the body leading.
    private func extraLeading(size: CGFloat) -> CGFloat {
        let target = size * (role.usesHeadingScale ? 1.15 : AppFont.bodyLeading)
        let name = switch role {
        case .partTitle: "CormorantGaramond-Medium"
        case .itemTitle: "CormorantGaramond-SemiBold"
        case .prayer, .response: "PlusJakartaSans-Regular"
        }
        let font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        return max(0, target - font.lineHeight)
    }

    private func font(size: CGFloat) -> Font {
        switch role {
        case .partTitle:
            AppFont.heading(size: size)
        case .itemTitle:
            AppFont.title(size: size)
        case .prayer, .response:
            AppFont.body(size: size)
        }
    }
}

struct PLTopBar: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isWideLayout) private var isWide
    @Environment(AppNavigation.self) private var navigation

    private var showsBack: Bool { !navigation.path.isEmpty }

    var body: some View {
        if isWide && !showsBack {
            EmptyView()
        } else {
            bar
        }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            if showsBack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Back")
            }
            Button(action: navigation.showToday) {
                HStack(spacing: 8) {
                    Mark(height: 22)
                    Wordmark()
                }
                .frame(minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("PerfectLiturgy")
            .accessibilityHint("Returns to Today")
            Spacer(minLength: 8)
            Button(action: navigation.showAccount) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22))
                    .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Account")
        }
        .padding(.horizontal, 8)
        .foregroundStyle(palette.foreground.color)
        .frame(minHeight: 52)
        .background(palette.background.color)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border.color)
                .frame(height: 1)
        }
    }
}
