import SwiftUI

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @AppStorage("hasSeenDocumentCoachmark") private var hasSeenCoachmark = false
    @State private var showCoachmark = false
    @State private var showCoachmarkMenuHighlight = false

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
                onPaywallNeeded: { showPaywall = true },
                showCoachmarkHighlight: showCoachmarkMenuHighlight
            )
            .padding(.horizontal, 20)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .animation(.easeInOut(duration: 0.2), value: visible)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.showAddMenu)
        .overlay {
            if showCoachmark {
                coachmarkOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
            }
        }
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
            let hasDocs = await Task.detached(priority: .userInitiated) {
                !DocumentFileManager.shared.loadMetadata()
                    .filter { $0.fileExists }
                    .isEmpty
            }.value
            if hasDocs {
                hasSeenCoachmark = true
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(900))
            } catch {
                return
            }
            guard !hasSeenCoachmark else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showCoachmark = true
            }
        }
        .onChange(of: coordinator.showAddMenu) { _, open in
            if open {
                guard !hasSeenCoachmark else { return }
                if showCoachmark {
                    withAnimation(.easeOut(duration: 0.2)) { showCoachmark = false }
                    showCoachmarkMenuHighlight = true
                }
                hasSeenCoachmark = true
            } else {
                showCoachmarkMenuHighlight = false
            }
        }
    }
}

// MARK: - Coachmark overlay

private extension DashboardView {
    var coachmarkOverlay: some View {
        GeometryReader { geo in
            // Use at least 34pt safe area bottom as fallback (common iPhone home-indicator height)
            let safeBottom = max(geo.safeAreaInsets.bottom, 34)
            let fabCenterX = geo.size.width - 48
            let fabCenterY = geo.size.height - safeBottom - 44
            let spotR: CGFloat = 38

            ZStack {
                // Spotlight dim: compositingGroup + destinationOut creates a true transparent hole
                ZStack {
                    Color.black.opacity(0.5)
                    Circle()
                        .fill(Color.black)
                        .frame(width: spotR * 2, height: spotR * 2)
                        .position(x: fabCenterX, y: fabCenterY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .allowsHitTesting(false)

                // Tap-absorb layer with hole at FAB — taps in the FAB circle fall through
                Color.clear
                    .contentShape(SpotlightPassthroughShape(
                        center: CGPoint(x: fabCenterX, y: fabCenterY),
                        radius: spotR
                    ))
                    .onTapGesture {}

                // Callout above the FAB spotlight
                DocumentCoachmarkCallout()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, safeBottom + 110)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Spotlight passthrough shape

private struct SpotlightPassthroughShape: Shape {
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Outer rect clockwise → winding +1 inside
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        // Inner circle counter-clockwise (clockwise: true in UIKit Y-down coords) → winding -1 inside
        // Net winding inside circle = 0 → excluded from hit testing
        path.move(to: CGPoint(x: center.x + radius, y: center.y))
        path.addArc(center: center, radius: radius,
                    startAngle: .zero, endAngle: .init(degrees: 360), clockwise: true)
        path.closeSubpath()
        return path
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
