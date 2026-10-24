import UIKit

enum AppChrome {
    static func apply() {
        let background = Palette.dynamic(\.background)
        let foreground = Palette.dynamic(\.foreground)
        let primary = Palette.dynamic(\.primary)
        let border = Palette.dynamic(\.border)
        let card = Palette.dynamic(\.card)
        let jakarta = UIFont(name: "PlusJakartaSans-Regular", size: 11) ?? .systemFont(ofSize: 11)
        let jakartaSemibold = UIFont(name: "PlusJakartaSans-SemiBold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = background
        navigation.shadowColor = border
        navigation.titleTextAttributes = [
            .foregroundColor: foreground,
            .font: jakartaSemibold,
        ]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = primary

        let item = UITabBarItemAppearance()
        item.normal.iconColor = foreground
        item.normal.titleTextAttributes = [
            .foregroundColor: foreground,
            .font: jakarta,
        ]
        item.selected.iconColor = primary
        item.selected.titleTextAttributes = [
            .foregroundColor: primary,
            .font: jakarta,
        ]

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = card
        tab.shadowColor = border
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
