import SwiftUI

struct ProfileView: View {
    @State private var showHealthProfile = false
    @State private var showLogOutAlert = false
    @State private var showDeleteAlert = false
    @State private var titleAppear = false
    @State private var contentAppear = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.displayXL)
                        .foregroundColor(.textPrimary)
                        .padding(.top, 24)
                        .opacity(titleAppear ? 1 : 0)
                        .offset(y: titleAppear ? 0 : -20)

                    VStack(spacing: 11) {
                        NeuraProCard()

                        SettingsRow(icon: "profile", title: "Health Profile") {
                            showHealthProfile = true
                        }
                        SettingsRow(icon: "sub", title: "Subscription")
                        SettingsRow(icon: "sec", title: "Security")
                        SettingsRow(icon: "lan", title: "Language")

                        SettingsRow(icon: "fav", title: "Feedback")
                        SettingsRow(icon: "fav", title: "Contact Us")

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
                    .opacity(contentAppear ? 1 : 0)
                    .offset(y: contentAppear ? 0 : 20)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showHealthProfile) {
                HealthProfileView()
            }
        }
        .alert("Log Out", isPresented: $showLogOutAlert) {
            Button("Log Out", role: .destructive) {
                handleLogOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                handleDeleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleAppear = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                contentAppear = true
            }
        }
    }
}

// MARK: - Actions

private extension ProfileView {
    func handleLogOut() {
        UserDefaults.standard.removeObject(forKey: "health_profile_data")
        // TODO: Clear session, navigate to onboarding
    }

    func handleDeleteAccount() {
        UserDefaults.standard.removeObject(forKey: "health_profile_data")
        // TODO: Call API to delete account, clear all data, navigate to onboarding
    }
}

#Preview {
    ProfileView()
}
