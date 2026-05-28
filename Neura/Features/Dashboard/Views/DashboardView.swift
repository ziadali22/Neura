import SwiftUI

struct DashboardView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        ZStack {
            // MARK: Tab Content
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

            // Dim overlay — sits behind the safeAreaInset tab bar/card
            if coordinator.showAddMenu {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            coordinator.showAddMenu = false
                        }
                    }
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !coordinator.isInDetailView && !coordinator.isSelectingDocs {
                CustomTabBar(
                    selectedTab: $coordinator.selectedTab,
                    isMenuOpen: $coordinator.showAddMenu,
                    onAction: { action in
                        coordinator.pendingAddAction = action
                        coordinator.selectedTab = .docs
                    }
                )
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.isInDetailView)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.showAddMenu)
        .environmentObject(coordinator)
    }
}

#Preview {
    DashboardView()
}
