import SwiftUI

struct PlaceholderPage<Accessory: View>: View {
    let title: String
    var note: String = "Nothing here yet."
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color("plForeground"))
            Text(note)
                .font(.body)
                .foregroundStyle(Color("plMutedForeground"))
            accessory()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color("plBackground"))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension PlaceholderPage where Accessory == EmptyView {
    init(title: String, note: String = "Nothing here yet.") {
        self.init(title: title, note: note) {
            EmptyView()
        }
    }
}

struct PlaceholderLink: View {
    let title: String
    let route: AppRoute

    var body: some View {
        NavigationLink(value: route) {
            Text(title)
                .font(.body)
                .foregroundStyle(Color("plPrimary"))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }
}
