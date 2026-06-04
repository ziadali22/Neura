import SwiftUI

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppCoordinator.Tab
    @Binding var isMenuOpen: Bool
    let onAction: (AppCoordinator.AddDocumentAction) -> Void
    var canUpload: Bool = true
    var onPaywallNeeded: () -> Void = {}
    var showCoachmarkHighlight: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightPulse = false

    private let spring: Animation = .spring(response: 0.45, dampingFraction: 0.80)

    // MARK: - Actions

    private struct ActionItem {
        let icon: String
        let title: String
        let subtitle: String
        let action: AppCoordinator.AddDocumentAction
    }

    private let actions: [ActionItem] = [
        .init(icon: "scanAdd",  title: "Scan Document",      subtitle: "Use camera to scan pages",          action: .scan),
        .init(icon: "imageAdd", title: "Upload from Photos", subtitle: "Choose an image from your library", action: .photo),
        .init(icon: "fileAdd",  title: "Import File",        subtitle: "Select a PDF or image file",        action: .file),
    ]

    // MARK: - Body

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Pill slot — card grows upward from the same base as the pill
            ZStack(alignment: .bottom) {
                // Card expands upward; bottom stays pinned to pill bottom
                if isMenuOpen {
                    expandedCard
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            )
                        )
                }

                // Pill fades out when card is visible (keeps width stable)
                tabPill
                    .opacity(isMenuOpen ? 0 : 1)
            }

            fab
        }
        .padding(.bottom, 16)
        .animation(reduceMotion ? .easeInOut(duration: 0.22) : spring, value: isMenuOpen)
    }

    // MARK: - Expanded Card

    private var expandedCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().padding(.leading, 72)
                }
                actionRow(item)
            }
        }
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: -4)
        .contentShape(Rectangle())
        .onTapGesture {}
        .onAppear {
            guard showCoachmarkHighlight else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                highlightPulse = true
            }
        }
        .onDisappear { highlightPulse = false }
    }

    private func actionRow(_ item: ActionItem) -> some View {
        Button {
            fire(item.action)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: "E7E0D8").opacity(0.6))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(item.icon)
                            .font(.system(size: 23))
                            .foregroundStyle(Color.accent)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background {
                if showCoachmarkHighlight {
                    Color.accent.opacity(highlightPulse ? 0.12 : 0.04)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.subtitle)
    }

    // MARK: - Normal Tab Pill

    private var tabPill: some View {
        HStack(spacing: 0) {
            ForEach(AppCoordinator.Tab.allCases) { tab in
                TabBarButton(tab: tab, isSelected: selectedTab == tab) {
                    selectedTab = tab
                }
            }
        }
        .padding(5)
        .background(Color.surfaceWhite)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            HapticManager.medium()
            if canUpload {
                isMenuOpen.toggle()
            } else {
                onPaywallNeeded()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(isMenuOpen ? 45 : 0))
                .animation(reduceMotion ? .easeInOut(duration: 0.22) : spring, value: isMenuOpen)
                .frame(width: 56, height: 56)
                .background(Color.accent)
                .clipShape(Circle())
                .shadow(color: Color.accent.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMenuOpen ? "Close" : "Add document")
    }

    // MARK: - Helpers

    private func fire(_ action: AppCoordinator.AddDocumentAction) {
        HapticManager.medium()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.22) : spring) {
            isMenuOpen = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onAction(action)
        }
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton: View {
    let tab: AppCoordinator.Tab
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(isSelected ? tab.selectedIcon : tab.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)

                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(isSelected ? Color.backgroundCard : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Tab metadata

extension AppCoordinator.Tab: CaseIterable, Identifiable {
    public var id: Int { rawValue }
    public static var allCases: [AppCoordinator.Tab] { [.profile, .home, .docs] }

    var label: String {
        switch self {
        case .profile: "Profile"
        case .home:    "Home"
        case .docs:    "Docs"
        }
    }

    var icon: String {
        switch self {
        case .profile: "profileUnselected"
        case .home:    "homeUnselected"
        case .docs:    "fileUnselected"
        }
    }

    var selectedIcon: String {
        switch self {
        case .profile: "profileSelected"
        case .home:    "homeSelected"
        case .docs:    "fileSelected"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.backgroundPrimary.ignoresSafeArea()
        CustomTabBar(
            selectedTab: .constant(.home),
            isMenuOpen: .constant(true),
            onAction: { _ in }
        )
        .padding(.horizontal, 20)
    }
}
