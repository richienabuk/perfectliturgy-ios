import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    @State private var showsMore = false
    @State private var pendingRoute: AppRoute?

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            Group {
                if isWide {
                    wideShell
                } else {
                    phoneTabs
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self, destination: RouteScreen.init)
        }
        .sheet(isPresented: $showsMore, onDismiss: commitPendingRoute) {
            MoreSheet(onSelect: stage)
        }
    }

    private var phoneTabs: some View {
        TabView(selection: tabSelection) {
            TodayView()
                .tag(AppTab.today)
                .tabItem { tabLabel(.today) }
            ReadingsView()
                .tag(AppTab.readings)
                .tabItem { tabLabel(.readings) }
            HymnsView()
                .tag(AppTab.hymns)
                .tabItem { tabLabel(.hymns) }
            SavedView()
                .tag(AppTab.saved)
                .tabItem { tabLabel(.saved) }
            Color.clear
                .tag(AppTab.more)
                .tabItem { tabLabel(.more) }
        }
        .tint(palette.primary.color)
    }

    private var wideShell: some View {
        VStack(spacing: 0) {
            TabletTopBar()
            HStack(spacing: 0) {
                LibrarySidebar()
                Rectangle()
                    .fill(palette.border.color)
                    .frame(width: 1)
                tabScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(palette.background.color)
    }

    @ViewBuilder
    private var tabScreen: some View {
        switch navigation.tab {
        case .today: TodayView()
        case .readings: ReadingsView()
        case .hymns: HymnsView()
        case .saved: SavedView()
        case .more: Color.clear
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            navigation.tab
        } set: { newValue in
            if newValue == .more {
                showsMore = true
            } else {
                navigation.tab = newValue
            }
        }
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
    }

    private func stage(_ route: AppRoute) {
        pendingRoute = route
        showsMore = false
    }

    private func commitPendingRoute() {
        guard let pendingRoute else { return }
        navigation.path.append(pendingRoute)
        self.pendingRoute = nil
    }
}

#Preview {
    RootView()
        .modelContainer(try! HymnStore.make(inMemory: true))
        .environment(DesignPreferences())
        .environment(AppNavigation())
        .resolvePalette()
}
