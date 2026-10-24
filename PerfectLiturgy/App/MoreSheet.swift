import SwiftUI

struct MoreSheet: View {
    let onSelect: (AppRoute) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Mark(height: 56)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
                ForEach(MoreMenu.sections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            Button {
                                onSelect(row.route)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: row.systemImage)
                                        .frame(width: 24)
                                        .foregroundStyle(Color("plPrimary"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.title)
                                            .foregroundStyle(Color("plForeground"))
                                        Text(row.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(Color("plMutedForeground"))
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color("plBackground"))
        }
        .tint(Color("plPrimary"))
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(18)
        .presentationBackground(Color("plBackground"))
    }
}
