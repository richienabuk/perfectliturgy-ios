import SwiftUI

struct MoreSheet: View {
    let onSelect: (AppRoute) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Mark(height: 56)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(palette.background.color)
                }
                ForEach(MoreMenu.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            Button {
                                onSelect(row.route)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: row.systemImage)
                                        .font(.system(size: 18))
                                        .frame(width: 24)
                                        .foregroundStyle(palette.primary.color)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(row.title)
                                            .font(AppFont.interface(size: 16, weight: .semibold))
                                            .foregroundStyle(palette.foreground.color)
                                        Text(row.subtitle)
                                            .font(AppFont.body(size: 14))
                                            .foregroundStyle(palette.mutedForeground.color)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .frame(minHeight: ControlMetrics.minimumHeight)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                            .listRowBackground(palette.background.color)
                        }
                    } header: {
                        Text(section.title)
                            .font(AppFont.interface(size: 13, weight: .semibold))
                            .foregroundStyle(palette.mutedForeground.color)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .listRowSeparatorTint(palette.border.color)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(palette.background.color)
        }
        .tint(palette.primary.color)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(palette.background.color)
    }
}
