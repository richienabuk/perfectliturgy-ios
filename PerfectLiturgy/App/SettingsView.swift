import SwiftUI

struct SettingsView: View {
    @Environment(DesignPreferences.self) private var design
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    appearance
                    sample
                    sliders
                    autoSync
                    account
                }
                .padding(.horizontal, isWide ? 28 : 20)
                .padding(.vertical, 24)
                .frame(maxWidth: isWide ? 840 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.background.color)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            PLHeading(lead: "Settings", size: 40)
            Text("Set the reading surface to suit you.")
                .font(AppFont.body())
                .foregroundStyle(palette.mutedForeground.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appearance: some View {
        PLCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(AppFont.interface(size: 16, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                Text("System follows this device.")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(palette.mutedForeground.color)
                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases) { mode in
                        PLChip(title: mode.title, isSelected: design.appearance == mode) {
                            design.setAppearance(mode)
                        }
                    }
                }
            }
        }
    }

    private var sample: some View {
        let scale = design.readingScale
        return PLCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reading sample")
                    .font(AppFont.interface(size: 16, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                Text("Part title")
                    .font(AppFont.heading(size: scale.size(for: .partTitle)))
                    .foregroundStyle(palette.foreground.color)
                    .accessibilityIdentifier("settings.sample.heading")
                Text("This line follows the body size.")
                    .font(AppFont.body(size: scale.size(for: .prayer)))
                    .foregroundStyle(palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.sample.body")
            }
        }
    }

    private var sliders: some View {
        PLCard {
            VStack(alignment: .leading, spacing: 18) {
                scaleSlider("Heading size", value: design.headingScale) { design.setHeadingScale($0) }
                scaleSlider("Body size", value: design.bodyScale) { design.setBodyScale($0) }
            }
        }
    }

    private var autoSync: some View {
        PLCard {
            Toggle(isOn: Binding(get: { design.autoSync }, set: { design.setAutoSync($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto sync")
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    Text("Only on Wi-Fi or an unmetered plan.")
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(palette.primary.color)
            .frame(minHeight: ControlMetrics.minimumHeight)
        }
    }

    private var account: some View {
        NavigationLink(value: AppRoute.account) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account")
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    Text("Sign-in and sync")
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(palette.mutedForeground.color)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("settings.account")
    }

    private func scaleSlider(_ title: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppFont.interface(size: 16, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                Spacer(minLength: 8)
                Text(value, format: .number.precision(.fractionLength(1)))
                    .font(AppFont.interface(size: 14))
                    .foregroundStyle(palette.mutedForeground.color)
                    .accessibilityHidden(true)
            }
            Slider(value: Binding(get: { value }, set: set), in: ReadingScale.bounds)
                .tint(palette.primary.color)
                .accessibilityLabel(title)
        }
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "settings-preview") ?? .standard
    let design = DesignPreferences(defaults: defaults)
    SettingsView()
        .environment(design)
        .environment(AppNavigation())
        .environment(\.readingScale, design.readingScale)
        .resolvePalette()
}
