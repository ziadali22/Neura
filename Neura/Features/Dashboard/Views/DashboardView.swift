import SwiftUI

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @AppStorage("hasSeenDocumentCoachmark") private var hasSeenCoachmark = false
    @State private var showCoachmark = false

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

            // MARK: Coachmark overlay
            if showCoachmark && !coordinator.showAddMenu {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .onTapGesture {}          // swallow taps — only the FAB tap dismisses
                    .transition(.opacity)

                GeometryReader { geo in
                    DocumentCoachmarkCallout()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 20)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 80)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing))
                )
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCoachmark)
        .environmentObject(coordinator)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await requestTrackingAfterSettling()
        }
        .task {
            guard !hasSeenCoachmark else { return }
            let hasDocs = !DocumentFileManager.shared.loadMetadata()
                .filter { $0.fileExists }
                .isEmpty
            if hasDocs {
                hasSeenCoachmark = true
                return
            }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showCoachmark = true
            }
        }
        .onChange(of: coordinator.showAddMenu) { _, open in
            guard open, showCoachmark else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showCoachmark = false
            }
            hasSeenCoachmark = true
        }
    }
}

// MARK: - ATT

private extension DashboardView {
    func requestTrackingAfterSettling() async {
        // Give the dashboard/splash transition a moment before the system dialog appears.
        try? await Task.sleep(for: .seconds(2))
        await ATTrackingService.requestIfNeeded()
    }
}

#Preview {
    DashboardView()
}
