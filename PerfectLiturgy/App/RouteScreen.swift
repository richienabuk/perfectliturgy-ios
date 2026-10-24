import SwiftUI

struct RouteScreen: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .orderOfMass:
            OrderOfMassView()
        case .rosary:
            RosaryView()
        case .stations:
            StationsView()
        case .station(let order):
            StationView(order: order)
        case .litanies:
            LitaniesView()
        case .litany(let id):
            LitanyView(id: id)
        case .prayers:
            PrayersView()
        case .prayer(let id):
            PrayerView(id: id)
        case .downloads:
            DownloadsView()
        case .settings:
            SettingsView()
        case .account:
            AccountView()
        case .massTimes:
            MassTimesView()
        case .donate:
            DonateView()
        case .hymn(let id):
            HymnDetailView(id: id)
        }
    }
}
