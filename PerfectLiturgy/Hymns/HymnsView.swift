import SwiftUI

struct HymnsView: View {
    var body: some View {
        PlaceholderPage(title: "Hymns") {
            PlaceholderLink(title: "Hymn", route: .hymn(id: "sample"))
        }
    }
}
