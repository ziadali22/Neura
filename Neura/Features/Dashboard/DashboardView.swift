import SwiftUI

struct DashboardView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ProfileView()
                .environmentObject(coordinator.profileRouter)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppCoordinator.Tab.profile)

            HomeView()
                .environmentObject(coordinator.homeRouter)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppCoordinator.Tab.home)

            DocsView()
                .environmentObject(coordinator.docsRouter)
                .tabItem { Label("Docs", systemImage: "doc.text.fill") }
                .tag(AppCoordinator.Tab.docs)
        }
        .tint(.orange)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environmentObject(coordinator)
    }
}

#Preview {
    DashboardView()
}
