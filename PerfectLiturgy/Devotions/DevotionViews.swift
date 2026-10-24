import SwiftUI

struct OrderOfMassView: View {
    var body: some View {
        PlaceholderPage(title: "Order of Mass")
    }
}

struct RosaryView: View {
    var body: some View {
        PlaceholderPage(title: "Holy Rosary")
    }
}

struct StationsView: View {
    var body: some View {
        PlaceholderPage(title: "Stations of the Cross") {
            PlaceholderLink(title: "Station", route: .station(order: 1))
        }
    }
}

struct StationView: View {
    let order: Int

    var body: some View {
        PlaceholderPage(title: "Station")
            .accessibilityIdentifier("station.\(order)")
    }
}

struct LitaniesView: View {
    var body: some View {
        PlaceholderPage(title: "Litanies") {
            PlaceholderLink(title: "Litany", route: .litany(id: "sample"))
        }
    }
}

struct LitanyView: View {
    let id: String

    var body: some View {
        PlaceholderPage(title: "Litany")
            .accessibilityIdentifier("litany.\(id)")
    }
}

struct PrayersView: View {
    var body: some View {
        PlaceholderPage(title: "Special Prayers") {
            PlaceholderLink(title: "Prayer", route: .prayer(id: "sample"))
        }
    }
}

struct PrayerView: View {
    let id: String

    var body: some View {
        PlaceholderPage(title: "Prayer")
            .accessibilityIdentifier("prayer.\(id)")
    }
}
