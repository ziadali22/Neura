import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: HomeRouter
    @State private var greetingAppear = false
    @State private var profileCardAppear = false
    @State private var completeCardAppear = false
    @State private var recentAppear = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Good morning")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "#1f1f1f"))
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .opacity(greetingAppear ? 1 : 0)
                        .offset(y: greetingAppear ? 0 : -20)

                    VStack(alignment: .leading, spacing: 24) {
                        SecureProfileCard(
                            name: "CRISTINA\nGAFITESCU",
                            location: "Iasi, Romania",
                            backgroundImage: "BG6",
                            onShareTap: { showShareSheet = true },
                            onTap: { router.push(.healthProfileDetail) }
                        )
                        .scaleEffect(profileCardAppear ? 1 : 0.95)
                        .opacity(profileCardAppear ? 1 : 0)

                        CompleteProfileCard()
                            .offset(y: completeCardAppear ? 0 : 30)
                            .opacity(completeCardAppear ? 1 : 0)
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 24) {
                        Text("Recent")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#1f1f1f"))
                            .padding(.horizontal, 20)

                        Text("Nothing here yet. Add or scan\na document")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#7a7a7a"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                    }
                    .opacity(recentAppear ? 1 : 0)
                }
            }
            .background(Color(hex: "#fcfaf8"))
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .healthProfileDetail:
                    HealthProfileDetailView()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareHealthProfileSheet()
                    .presentationDetents([.height(525)])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    greetingAppear = true
                }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                    profileCardAppear = true
                }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                    completeCardAppear = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    recentAppear = true
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeRouter())
}
