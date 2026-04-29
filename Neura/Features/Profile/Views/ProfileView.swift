import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var router: ProfileRouter
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showLogOutAlert = false
    @State private var showDeleteAlert = false
    @State private var showPaywall = false
    @State private var titleAppear = false
    @State private var contentAppear = false

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Profile")
                        .font(.displayXL)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .opacity(titleAppear ? 1 : 0)
                        .offset(y: titleAppear ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: titleAppear)

                    VStack(alignment: .leading, spacing: 0) {
                        // Neura Pro
                        NeuraProCard()
                            .padding(.bottom, 20)

                        // Profile section
                        ProfileSectionHeader(title: "Profile")
                        VStack(spacing: 11) {
                            SettingsRow(icon: "profile", title: "Health Profile") {
                                router.push(.healthProfile)
                            }
                            SettingsRow(icon: "sub", title: "Subscription") {
                                showPaywall = true
                            }
                        }
                        .padding(.bottom, 20)

                        // Preferences section
                        ProfileSectionHeader(title: "Preferences")
                        VStack(spacing: 11) {
                            SettingsRow(icon: "sec", title: "Security")
                            SettingsRow(icon: "lan", title: String(localized: "Language")) {
                                router.push(.language)
                            }
                        }
                        .padding(.bottom, 20)

                        // Support section
                        ProfileSectionHeader(title: "Support")
                        VStack(spacing: 11) {
                            SettingsRow(icon: "fav", title: "Feedback")
                            SettingsRow(icon: "fav", title: "Contact Us")
                        }
                        .padding(.bottom, 20)

                        // Account section
                        ProfileSectionHeader(title: "Account")
                        VStack(spacing: 11) {
                            SettingsRow(
                                icon: "logout",
                                title: "Log Out",
                                showChevron: false
                            ) {
                                showLogOutAlert = true
                            }
                            SettingsRow(
                                icon: "delete",
                                title: "Delete Account",
                                style: .destructive,
                                showChevron: false
                            ) {
                                showDeleteAlert = true
                            }
                        }
                    }
                    .opacity(contentAppear ? 1 : 0)
                    .offset(y: contentAppear ? 0 : 20)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: contentAppear)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color.backgroundPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .healthProfile:
                    HealthProfileView()
                case .language:
                    LanguagePickerView()
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Log Out", isPresented: $showLogOutAlert) {
            Button("Log Out", role: .destructive, action: handleLogOut)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: handleDeleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .onAppear {
            titleAppear = true
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                contentAppear = true
            }
        }
    }
}

// MARK: - Section Header

private struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.captionS)
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }
}

// MARK: - Actions

private extension ProfileView {
    func handleLogOut() {
        // Clear all local user data
        let keys = ["health_profile_data", "hasCompletedOnboarding",
                    "user_location", "onboarding_medical_areas",
                    "neura_document_upload_count", "neura_share_count", "neura_is_pro"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        // Sign out from Firebase — AuthService publishes isSignedIn=false,
        // which causes NeuraApp to switch back to OnboardingView.
        AuthService.shared.signOut()
    }

    func handleDeleteAccount() {
        Task {
            // Clear local data first
            let keys = ["health_profile_data", "hasCompletedOnboarding",
                        "user_location", "onboarding_medical_areas",
                        "neura_document_upload_count", "neura_share_count", "neura_is_pro"]
            keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
            // Delete Firebase Auth account (Phase 4: also delete Storage/Firestore data via Cloud Function)
            try? await AuthService.shared.deleteAccount()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(ProfileRouter())
}
