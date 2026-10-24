import Foundation

nonisolated enum AppRoute: Hashable, Sendable {
    case orderOfMass
    case rosary
    case stations
    case station(order: Int)
    case litanies
    case litany(id: String)
    case prayers
    case prayer(id: String)
    case downloads
    case settings
    case account
    case massTimes
    case donate
    case hymn(id: String)

    var title: String {
        switch self {
        case .orderOfMass: "Order of Mass"
        case .rosary: "Holy Rosary"
        case .stations: "Stations of the Cross"
        case .station: "Station"
        case .litanies: "Litanies"
        case .litany: "Litany"
        case .prayers: "Special Prayers"
        case .prayer: "Prayer"
        case .downloads: "Downloads"
        case .settings: "Settings"
        case .account: "Account"
        case .massTimes: "Mass Times"
        case .donate: "Donate"
        case .hymn: "Hymn"
        }
    }
}
