import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: HomeRouter
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @StateObject private var healthVM = HealthProfileViewModel()
    @State private var recentDocuments: [Document] = []
    @State private var greetingAppear = false
    @State private var bannerAppear = false
    @State private var profileCardAppear = false
    @State private var completeCardAppear = false
    @State private var recentAppear = false
    @State private var showShareSheet = false
    @State private var showPaywall = false
    @State private var showBackgroundPicker = false
    @State private var selectedDocument: Document?
    @State private var cardBackground: CardBackground = CardBackground.saved()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = String(localized: "Good morning")
        case 12..<18: base = String(localized: "Good afternoon")
        default: base = String(localized: "Good evening")
        }
        let firstName = healthVM.profile.generalData.fullName
            .components(separatedBy: " ").first ?? ""
        return firstName.isEmpty ? base : "\(base), \(firstName)"
    }

    private var formattedCardName: String {
        let parts = healthVM.profile.generalData.fullName
            .uppercased()
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "" }
        if parts.count == 1 { return parts[0] }
        return "\(parts[0])\n\(parts.dropFirst().joined(separator: " "))"
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Greeting
                    Text(greeting)
                        .font(.displayXL)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .opacity(greetingAppear ? 1 : 0)
                        .offset(y: greetingAppear ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: greetingAppear)

                    // MARK: - Upload Limit Banner
                    if !subscriptionManager.isPro && !subscriptionManager.canUpload {
                        UploadLimitBanner(
                            subscriptionManager: subscriptionManager,
                            onTap: { showPaywall = true }
                        )
                        .padding(.horizontal, 24)
                        .opacity(bannerAppear ? 1 : 0)
                        .offset(y: bannerAppear ? 0 : -10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: bannerAppear)
                    }

                    // MARK: - Profile Cards
                    VStack(alignment: .leading, spacing: 16) {
                        SecureProfileCard(
                            name: healthVM.profile.generalData.fullName,
                            location: UserDefaults.standard.string(forKey: "user_location") ?? "",
                            background: cardBackground,
                            onShareTap: { showShareSheet = true },
                            onCustomizeTap: { showBackgroundPicker = true },
                            onTap: { authenticateAndOpenProfile() }
                        )
                        .scaleEffect(profileCardAppear ? 1 : 0.95)
                        .opacity(profileCardAppear ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: profileCardAppear)

                        CompleteProfileCard(onTap: { router.push(.healthProfileDetail) })
                            .offset(y: completeCardAppear ? 0 : 30)
                            .opacity(completeCardAppear ? 1 : 0)
                            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: completeCardAppear)
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Emergency Card
                    EmergencyCardBanner { router.push(.emergencyCard) }
                        .padding(.horizontal, 20)
                        .opacity(completeCardAppear ? 1 : 0)
                        .offset(y: completeCardAppear ? 0 : 20)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: completeCardAppear)

                    // MARK: - Recent Documents
                    RecentDocumentsSection(
                        documents: recentDocuments,
                        onDocumentTap: { selectedDocument = $0 }
                    )
                    .opacity(recentAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: recentAppear)

                    Spacer(minLength: 80)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.backgroundPrimary)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .healthProfileDetail:
                    HealthProfileDetailView()
                case .emergencyCard:
                    EmergencyCardView()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareHealthProfileSheet()
                    .presentationDetents([.height(525)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBackgroundPicker) {
                CardBackgroundPickerSheet(selected: $cardBackground)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(subscriptionManager: subscriptionManager)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedDocument) { document in
                NavigationStack {
                    DocumentViewerView(document: document, onDelete: {
                        selectedDocument = nil
                        loadRecentDocuments()
                    }, onRename: { _ in
                        loadRecentDocuments()
                    })
                }
            }
            .onAppear {
                loadRecentDocuments()
                animateEntrance()
            }
        }
    }

    // MARK: - Actions

    private func authenticateAndOpenProfile() {
        Task {
            if await biometricAuth.authenticate() {
                router.push(.healthProfileDetail)
            }
        }
    }

    // MARK: - Data Loading

    private func loadRecentDocuments() {
        recentDocuments = DocumentFileManager.shared.loadMetadata()
            .filter { $0.fileExists }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Animations

    private func animateEntrance() {
        greetingAppear = true
        bannerAppear = true

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

// MARK: - Recent Documents Section

private struct RecentDocumentsSection: View {
    let documents: [Document]
    let onDocumentTap: (Document) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)

            if documents.isEmpty {
                Text("Nothing here yet — scan or upload a document.")
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(documents.prefix(5).enumerated()), id: \.element.id) { index, document in
                        RecentDocumentRow(document: document) { onDocumentTap(document) }

                        if index < min(documents.count, 5) - 1 {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeRouter())
}
