import SwiftUI

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppCoordinator.Tab
    let onAddTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Floating pill
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

            // FAB — always visible
            Button("Add document", systemImage: "plus", action: onAddTap)
                .labelStyle(.iconOnly)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accent)
                .clipShape(Circle())
                .shadow(color: Color.accent.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.15)
                : .spring(response: 0.3, dampingFraction: 0.72),
            value: selectedTab
        )
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
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20))

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
        case .profile: "person"
        case .home:    "house"
        case .docs:    "doc.text"
        }
    }

    var selectedIcon: String {
        switch self {
        case .profile: "person.fill"
        case .home:    "house.fill"
        case .docs:    "doc.text.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.backgroundPrimary.ignoresSafeArea()
        CustomTabBar(selectedTab: .constant(.docs), onAddTap: {})
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
    }
}
