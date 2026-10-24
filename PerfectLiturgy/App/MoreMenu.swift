import Foundation

nonisolated enum MoreMenu {
    nonisolated struct Section: Identifiable, Sendable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }

    nonisolated struct Row: Identifiable, Sendable {
        let title: String
        let subtitle: String
        let systemImage: String
        let route: AppRoute
        var id: String { title }
    }

    static let sections: [Section] = [
        Section(title: "Order of Mass", rows: [
            Row(
                title: "Order of Mass",
                subtitle: "Fixed Mass texts in your downloaded languages",
                systemImage: "book.closed",
                route: .orderOfMass
            ),
        ]),
        Section(title: "Prayer & devotions", rows: [
            Row(
                title: "Holy Rosary",
                subtitle: "Mysteries and a step-by-step guide",
                systemImage: "circle.dotted",
                route: .rosary
            ),
            Row(
                title: "Stations of the Cross",
                subtitle: "Fourteen stations with reflections",
                systemImage: "cross",
                route: .stations
            ),
            Row(
                title: "Litanies",
                subtitle: "Saints, Our Lady, the Sacred Heart, and more",
                systemImage: "list.bullet",
                route: .litanies
            ),
            Row(
                title: "Special Prayers",
                subtitle: "A saved collection for daily life",
                systemImage: "text.book.closed",
                route: .prayers
            ),
        ]),
        Section(title: "App", rows: [
            Row(
                title: "Downloads",
                subtitle: "Manage languages and content packs",
                systemImage: "arrow.down.circle",
                route: .downloads
            ),
            Row(
                title: "Settings",
                subtitle: "Appearance, text size, and sync",
                systemImage: "gearshape",
                route: .settings
            ),
            Row(
                title: "Account",
                subtitle: "Sign-in and sync",
                systemImage: "person.crop.circle",
                route: .account
            ),
        ]),
        Section(title: "Discover & support", rows: [
            Row(
                title: "Mass Times",
                subtitle: "mass-times.perfectliturgy.com",
                systemImage: "clock",
                route: .massTimes
            ),
            Row(
                title: "Donate",
                subtitle: "perfectliturgy.com/donate",
                systemImage: "heart",
                route: .donate
            ),
        ]),
    ]
}
