import SwiftUI

struct SettingsView: View {
    @Environment(DesignPreferences.self) private var design
    @Environment(\.palette) private var palette

    var body: some View {
        PlaceholderPage(
            title: "Settings",
            note: "Set the reading surface to suit you."
        ) {
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
                                design.appearance = mode
                            }
                        }
                    }
                }
            }
        }
    }
}
