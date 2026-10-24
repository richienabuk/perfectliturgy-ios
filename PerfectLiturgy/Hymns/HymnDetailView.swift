import SwiftUI

struct HymnDetailView: View {
    let id: String

    var body: some View {
        PlaceholderPage(title: "Hymn")
            .accessibilityIdentifier("hymn.\(id)")
    }
}
