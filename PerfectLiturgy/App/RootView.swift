import SwiftUI

struct RootView: View {
    @State private var tab = AppTab.today
    @State private var path = NavigationPath()
    @State private var showsMore = false
    @State private var pendingRoute: AppRoute?

    var body: some View {
        NavigationStack(path: $path) {
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
            .tint(Color("plPrimary"))
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { shellToolbar }
            .navigationDestination(for: AppRoute.self, destination: RouteScreen.init)
        }
        .sheet(isPresented: $showsMore, onDismiss: commitPendingRoute) {
            MoreSheet(onSelect: stage)
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            tab
        } set: { newValue in
            if newValue == .more {
                showsMore = true
            } else {
                tab = newValue
            }
        }
    }

    @ToolbarContentBuilder
    private var shellToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button(action: showToday) {
                Wordmark()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("PerfectLiturgy")
            .accessibilityHint("Returns to Today")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: showAccount) {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("Account")
        }
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
    }

    private func showToday() {
        path = NavigationPath()
        tab = .today
    }

    private func showAccount() {
        path.append(AppRoute.account)
    }

    private func stage(_ route: AppRoute) {
        pendingRoute = route
        showsMore = false
    }

    private func commitPendingRoute() {
        guard let pendingRoute else { return }
        path.append(pendingRoute)
        self.pendingRoute = nil
    }
}

#Preview {
    RootView()
}
