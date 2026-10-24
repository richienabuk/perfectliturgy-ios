import SwiftUI

/// Wide-screen chrome. The phone keeps the tab bar.
struct TabletTopBar: View {
    @Environment(\.palette) private var palette
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Mark(height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Wordmark()
                    Text("Live the liturgical life. Participate fully in Mass and liturgy.")
                        .font(AppFont.interface(size: 12))
                        .foregroundStyle(palette.mutedForeground.color)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            Button(action: navigation.showAccount) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22))
                    .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Account")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(palette.background.color)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border.color).frame(height: 1)
        }
    }
}

struct LibrarySidebar: View {
    @Environment(\.palette) private var palette
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("LIBRARY")
                    .font(AppFont.eyebrow())
                    .tracking(AppFont.eyebrowTracking)
                    .foregroundStyle(palette.mutedForeground.color)
                    .padding(.horizontal, 8)
                sidebarGroup(title: "Your liturgy", rows: liturgy)
                sidebarGroup(title: "Prayer & liturgy", rows: prayer)
                sidebarGroup(title: "App", rows: appRows)
                Spacer(minLength: 12)
                Button {
                    open(.massTimes)
                } label: {
                    HStack {
                        Label("Mass Times", systemImage: "clock")
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(AppFont.interface(size: 14, weight: .medium))
                    .foregroundStyle(palette.foreground.color)
                    .frame(minHeight: ControlMetrics.minimumHeight)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(16)
        }
        .frame(width: 272)
        .frame(maxHeight: .infinity)
        .background(palette.secondary.color)
    }

    private var liturgy: [SidebarRow] {
        [
            SidebarRow(title: "Today", systemImage: "house", tab: .today),
            SidebarRow(title: "Daily readings", systemImage: "book.closed", tab: .readings),
            SidebarRow(title: "Hymns", systemImage: "music.note", tab: .hymns),
            SidebarRow(title: "Saved", systemImage: "bookmark", tab: .saved),
        ]
    }

    private var prayer: [SidebarRow] {
        [
            SidebarRow(title: "Order of Mass", systemImage: "book.closed", route: .orderOfMass),
            SidebarRow(title: "Holy Rosary", systemImage: "circle.dotted", route: .rosary),
            SidebarRow(title: "Stations of the Cross", systemImage: "cross", route: .stations),
            SidebarRow(title: "Litanies", systemImage: "list.bullet", route: .litanies),
            SidebarRow(title: "Special Prayers", systemImage: "text.book.closed", route: .prayers),
        ]
    }

    private var appRows: [SidebarRow] {
        [
            SidebarRow(title: "Downloads", systemImage: "arrow.down.circle", route: .downloads),
            SidebarRow(title: "Settings", systemImage: "gearshape", route: .settings),
            SidebarRow(title: "Account", systemImage: "person.crop.circle", route: .account),
        ]
    }

    private func sidebarGroup(title: String, rows: [SidebarRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.mutedForeground.color)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            ForEach(rows) { row in
                sidebarButton(row)
            }
        }
    }

    private func sidebarButton(_ row: SidebarRow) -> some View {
        let selected = row.tab == navigation.tab && navigation.path.isEmpty
        return Button {
            if let tab = row.tab {
                navigation.path = NavigationPath()
                navigation.tab = tab
            } else if let route = row.route {
                open(route)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: row.systemImage)
                    .frame(width: 18)
                Text(row.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if selected {
                    Circle()
                        .frame(width: 6, height: 6)
                }
            }
            .font(AppFont.interface(size: 15, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? palette.primaryForeground.color : palette.foreground.color)
            .padding(.horizontal, 12)
            .frame(minHeight: ControlMetrics.minimumHeight)
            .background(selected ? palette.primary.color : Color.clear, in: RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func open(_ route: AppRoute) {
        navigation.path.append(route)
    }
}

private struct SidebarRow: Identifiable {
    var title: String
    var systemImage: String
    var tab: AppTab?
    var route: AppRoute?
    var id: String { title }

    init(title: String, systemImage: String, tab: AppTab? = nil, route: AppRoute? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.tab = tab
        self.route = route
    }
}
