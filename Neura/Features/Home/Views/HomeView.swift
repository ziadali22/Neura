import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: HomeRouter
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @StateObject private var updateChecker = AppUpdateChecker.shared
    @StateObject private var healthVM = HealthProfileViewModel()
    @StateObject private var docsViewModel = DocumentsListViewModel()
    @State private var recentDocuments: [Document] = []
    @State private var greetingAppear = true
    @State private var bannerAppear = true
    @State private var profileCardAppear = true
    @State private var completeCardAppear = true
    @State private var recentAppear = true
    @State private var showShareSheet = false
    @State private var showPaywall = false
    @State private var showBackgroundPicker = false
    @State private var selectedDocument: Document?
    @State private var cardBackground: CardBackground = CardBackground.saved()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = L10n.Home.Greeting.morning
        case 12..<18: base = L10n.Home.Greeting.afternoon
        default: base = L10n.Home.Greeting.evening
        }
        let firstName = healthVM.profile.generalData.fullName
            .components(separatedBy: " ").first ?? ""
        return firstName.isEmpty ? base : "\(base)"
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
                        .font(.displaySemi)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .opacity(greetingAppear ? 1 : 0)
                        .offset(y: greetingAppear ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: greetingAppear)

                    // MARK: - Upload Limit Banner
                    // Shown for all free users from install onward; the banner itself
                    // swaps to an upsell once the upload limit is reached.
                    if !subscriptionManager.isPro {
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

                        CompleteProfileCard(
                            generalData: healthVM.profile.generalData,
                            onTap: { router.push(.healthProfile) }
                        )
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
                case .healthProfile:
                    HealthProfileView()
                case .healthProfileDetail:
                    HealthProfileDetailView()
                case .emergencyCard:
                    EmergencyCardView()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareHealthProfileSheet()
                    .presentationDetents([.height(490)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBackgroundPicker) {
                CardBackgroundPickerSheet(selected: $cardBackground)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(subscriptionManager: subscriptionManager)
            }
            .sheet(item: $updateChecker.availableUpdate) { update in
                AppUpdateSheet(update: update)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(32)
            }
            .sheet(item: $selectedDocument) { document in
                NavigationStack {
                    DocumentViewerView(document: document, onDelete: {
                        docsViewModel.loadDocuments()
                        docsViewModel.deleteDocument(document)
                        selectedDocument = nil
                        loadRecentDocuments()
                    }, onEdit: { metadata, preview in
                        docsViewModel.loadDocuments()
                        docsViewModel.updateDocument(document, metadata: metadata, preview: preview)
                        loadRecentDocuments()
                    })
                }
            }
            .onAppear {
                loadRecentDocuments()
                Task { await updateChecker.checkForUpdate() }
            }
            .onChange(of: router.path) {
                if router.path.isEmpty {
                    healthVM.reload()
                    loadRecentDocuments()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .documentsRestored)) { _ in
                loadRecentDocuments()
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthProfileRestored)) { _ in
                healthVM.reload()
            }
        }
    }

    // MARK: - Actions

    private func authenticateAndOpenProfile() {
        guard biometricAuth.isBiometricLockEnabled else {
            router.push(.healthProfileDetail)
            return
        }

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

}

// MARK: - Recent Documents Section

private struct RecentDocumentsSection: View {
    let documents: [Document]
    let onDocumentTap: (Document) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Home.recent)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)

            if documents.isEmpty {
                Text(L10n.Home.empty)
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(documents.prefix(5)) { document in
                        Button { onDocumentTap(document) } label: {
                            DocumentListRow(document: document)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeRouter())
}
