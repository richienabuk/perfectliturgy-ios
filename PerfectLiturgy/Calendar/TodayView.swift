import SwiftUI

struct TodayView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        PlaceholderPage(
            title: "Today",
            heading: "Readings and Hymns",
            emphasis: "for Mass today.",
            note: "Readings and saved Hymns in your languages."
        ) {
            PLButton(title: "Open readings") {
                navigation.tab = .readings
            }
        }
    }
}
