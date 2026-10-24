import SwiftUI

@Observable
final class AppNavigation {
    var tab: AppTab = .today
    var path = NavigationPath()

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
}
