import SwiftUI

struct DashboardView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

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
            let visible = !coordinator.isInDetailView && !coordinator.isSelectingDocs
            CustomTabBar(
                selectedTab: $coordinator.selectedTab,
                isMenuOpen: $coordinator.showAddMenu,
                onAction: { action in
                    coordinator.pendingAddAction = action
                    coordinator.selectedTab = .docs
                },
                canUpload: subscriptionManager.canUpload,
                onPaywallNeeded: { showPaywall = true }
            )
            .padding(.horizontal, 20)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .animation(.easeInOut(duration: 0.2), value: visible)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.showAddMenu)
        .environmentObject(coordinator)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .task {
            // Give the UI a moment to settle before the system dialog appears
            try? await Task.sleep(for: .seconds(1))
            await ATTrackingService.requestIfNeeded()
        }
    }
}

#Preview {
    DashboardView()
}
