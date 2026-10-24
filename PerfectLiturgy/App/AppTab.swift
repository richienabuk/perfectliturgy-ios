import Foundation

nonisolated enum AppTab: Hashable, Sendable {
    case today
    case readings
    case hymns
    case saved
    case more

    var title: String {
        switch self {
        case .today: "Today"
        case .readings: "Readings"
        case .hymns: "Hymns"
        case .saved: "Saved"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.horizon"
        case .readings: "book.closed"
        case .hymns: "music.note"
        case .saved: "bookmark"
        case .more: "ellipsis"
        }
    }
}
