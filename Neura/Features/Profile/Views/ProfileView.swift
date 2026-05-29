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
                    Text(L10n.Profile.title)
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
//                        ProfileSectionHeader(title: L10n.Profile.Section.profile)
                        VStack(spacing: 11) {
                            SettingsRow(icon: "profile", title: L10n.Profile.healthProfile) {
                                router.push(.healthProfile)
                            }
                            SettingsRow(icon: "sub", title: L10n.Profile.subscription) {
                                showPaywall = true
                            }
                            SettingsRow(icon: "sec", title: L10n.Profile.security)
                            SettingsRow(icon: "lan", title: L10n.Profile.language) {
                                router.push(.language)
                            }
                            SettingsRow(icon: "fav", title: L10n.Profile.feedback)
                            SettingsRow(icon: "Instagram", title: L10n.Profile.contactUs) {
                                if let url = URL(string: "https://www.instagram.com/myneura?igsh=MXd4YTVxb3p6amdxbw==") {
                                    UIApplication.shared.open(url)
                                }
                            }

                            SettingsRow(
                                icon: "logout",
                                title: L10n.Profile.logOut,
                                showChevron: false
                            ) {
                                showLogOutAlert = true
                            }
                            SettingsRow(
                                icon: "delete",
                                title: L10n.Profile.deleteAccount,
                                style: .destructive,
                                showChevron: false
                            ) {
                                showDeleteAlert = true
                            }
                        }
                        .padding(.bottom, 20)

                        // Preferences section
//                        ProfileSectionHeader(title: L10n.Profile.Section.preferences)
//                        VStack(spacing: 11) {
//                            SettingsRow(icon: "sec", title: L10n.Profile.security)
//                            SettingsRow(icon: "lan", title: L10n.Profile.language) {
//                                router.push(.language)
//                            }
//                        }
//                        .padding(.bottom, 20)

                        // Support section
//                        ProfileSectionHeader(title: L10n.Profile.Section.support)
//                        VStack(spacing: 11) {
//                            SettingsRow(icon: "fav", title: L10n.Profile.feedback)
//                            SettingsRow(icon: "Instagram", title: L10n.Profile.contactUs)
//                        }
//                        .padding(.bottom, 20)

                        // Account section
//                        ProfileSectionHeader(title: L10n.Profile.Section.account)
//                        VStack(spacing: 11) {
//                            SettingsRow(
//                                icon: "logout",
//                                title: L10n.Profile.logOut,
//                                showChevron: false
//                            ) {
//                                showLogOutAlert = true
//                            }
//                            SettingsRow(
//                                icon: "delete",
//                                title: L10n.Profile.deleteAccount,
//                                style: .destructive,
//                                showChevron: false
//                            ) {
//                                showDeleteAlert = true
//                            }
//                        }
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
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .alert(L10n.Profile.logOut, isPresented: $showLogOutAlert) {
            Button(L10n.Profile.logOut, role: .destructive, action: handleLogOut)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(L10n.Profile.logOutMessage)
        }
        .alert(L10n.Profile.deleteAccount, isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: handleDeleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(L10n.Profile.deleteAccountMessage)
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
