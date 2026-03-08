import SwiftUI

struct DashboardView: View {
    @State private var selectedTab = 1
    @State private var hideFloatingButton = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(0)

                HomeView(hideFloatingButton: $hideFloatingButton)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(1)

                DocsView()
                    .tabItem {
                        Label("Docs", systemImage: "doc.text.fill")
                    }
                    .tag(2)
            }
            .tint(.orange)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            // TODO: Re-enable floating button when ready
            // if !hideFloatingButton {
            //     FloatingAddButton {
            //         // TODO: Handle add action
            //     }
            //     .padding(.trailing, 24)
            //     .padding(.bottom, 50)
            //     .transition(.scale.combined(with: .opacity))
            //     .animation(.easeInOut(duration: 0.2), value: hideFloatingButton)
            // }
        }
    }
}

// MARK: - Floating Add Button

private struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.orange)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
        }
    }
}

#Preview {
    DashboardView()
}
