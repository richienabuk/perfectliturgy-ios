import SwiftUI

@Observable
final class AppNavigation {
    var tab: AppTab = .today
    var path = NavigationPath()
    var safariURL: URL?
    private(set) var syncRequest = 0
    var isSyncing = false

    func showToday() {
        path = NavigationPath()
        tab = .today
    }

    func showAccount() {
        path.append(AppRoute.account)
    }

    func showSaved() {
        path = NavigationPath()
        tab = .saved
    }

    func requestSync() {
        syncRequest += 1
    }

    func open(_ route: AppRoute) {
        switch route {
        case .massTimes:
            safariURL = WebLink.massTimes
        case .donate:
            safariURL = WebLink.donate
        default:
            path.append(route)
        }
    }
}
