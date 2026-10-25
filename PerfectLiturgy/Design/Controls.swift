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
    var trailingSystemImage: String? = nil
    var isEnabled: Bool = true
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
                .overlay(alignment: .trailing) {
                    if let trailingSystemImage {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(foreground)
                            .padding(.trailing, 16)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
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
    var weekMark: String?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(palette.liturgicalAccent.color)
                        .frame(width: 16, height: 1)
                    Text("LITURGICAL SEASON")
                        .font(AppFont.eyebrow())
                        .tracking(AppFont.eyebrowTracking)
                        .foregroundStyle(palette.liturgicalAccent.color)
                }
                Text(title)
                    .font(AppFont.title(size: 28))
                    .foregroundStyle(palette.liturgicalForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let weekMark {
                WeekMarkArch(mark: weekMark)
            }
        }
        .padding(20)
        .background(palette.liturgicalBackground.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
    }
}

/// Gold arch with the Ordinary Time week numeral, as on the forest banner.
struct WeekMarkArch: View {
    let mark: String

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            ArchOutline()
                .stroke(palette.liturgicalAccent.color, lineWidth: 1.5)
            Text(mark)
                .font(AppFont.title(size: 22))
                .foregroundStyle(palette.liturgicalAccent.color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 8)
        }
        .frame(width: 84, height: 72)
        .accessibilityLabel("Week \(mark)")
    }
}

private nonisolated struct ArchOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

struct ReadingText: View {
    let text: String
    var role: ReadingRole
    var tint: Color? = nil

    @Environment(\.palette) private var palette
    @Environment(\.readingScale) private var readingScale

    var body: some View {
        let size = readingScale.size(for: role)
        Text(text)
            .font(font(size: size))
            .foregroundStyle(tint ?? palette.foreground.color)
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
    /// A tab's own screen. It never shows a back button, and it does not read the navigation
    /// path, so pushing a screen does not redraw the bar on every tab.
    var isTabRoot = false

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isWideLayout) private var isWide
    @Environment(AppNavigation.self) private var navigation

    private var showsBack: Bool { !isTabRoot && !navigation.path.isEmpty }

    var body: some View {
        if isWide && !showsBack {
            EmptyView()
        } else if isWide {
            backRow
        } else {
            bar
        }
    }

    /// The tablet bar already carries the wordmark and account. A pushed screen only needs a way back.
    private var backRow: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Back")
            Spacer(minLength: 0)
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
            SyncHeaderButton()
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

struct SyncHeaderButton: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        Button(action: navigation.requestSync) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .semibold))
                .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
                .opacity(navigation.isSyncing ? 0.45 : 1)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Sync")
        .accessibilityIdentifier("header.sync")
    }
}
