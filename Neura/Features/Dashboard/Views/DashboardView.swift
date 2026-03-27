import SwiftUI

struct DashboardView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        ZStack {
            switch coordinator.selectedTab {
            case .profile:
                ProfileView()
                    .environmentObject(coordinator.profileRouter)
            case .home:
                HomeView()
                    .environmentObject(coordinator.homeRouter)
            case .docs:
                DocsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $coordinator.selectedTab) {
                coordinator.selectedTab = .docs
                coordinator.showAddDocument = true
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .environmentObject(coordinator)
    }
}

#Preview {
    DashboardView()
}
