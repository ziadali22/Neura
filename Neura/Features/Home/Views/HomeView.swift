import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: HomeRouter
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
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
        switch hour {
        case 5..<12: return String(localized: "Good morning")
        case 12..<18: return String(localized: "Good afternoon")
        default: return String(localized: "Good evening")
        }
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Greeting
                    Text(greeting)
                        .font(.displayXL)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .opacity(greetingAppear ? 1 : 0)
                        .offset(y: greetingAppear ? 0 : -20)

                    // MARK: - Upload Limit Banner
                    if !subscriptionManager.isPro && !subscriptionManager.canUpload {
                        UploadLimitBanner(
                            subscriptionManager: subscriptionManager,
                            onTap: { showPaywall = true }
                        )
                        .padding(.horizontal, 24)
                        .opacity(bannerAppear ? 1 : 0)
                        .offset(y: bannerAppear ? 0 : -10)
                    }

                    // MARK: - Profile Cards
                    VStack(alignment: .leading, spacing: 24) {
                        SecureProfileCard(
                            name: "ZIAD\nKHALIL",
                            location: UserDefaults.standard.string(forKey: "user_location") ?? "",
                            background: cardBackground,
                            onShareTap: { showShareSheet = true },
                            onCustomizeTap: { showBackgroundPicker = true },
                            onTap: {
                                Task {
                                    if await biometricAuth.authenticate() {
                                        router.push(.healthProfileDetail)
                                    }
                                }
                            }
                        )
                        .scaleEffect(profileCardAppear ? 1 : 0.95)
                        .opacity(profileCardAppear ? 1 : 0)

                        CompleteProfileCard(onTap: {
                            router.push(.healthProfileDetail)
                        })
                        .offset(y: completeCardAppear ? 0 : 30)
                        .opacity(completeCardAppear ? 1 : 0)
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Emergency Card
                    EmergencyCardBanner {
                        router.push(.emergencyCard)
                    }
                    .padding(.horizontal, 20)
                    .opacity(completeCardAppear ? 1 : 0)
                    .offset(y: completeCardAppear ? 0 : 20)

                    // MARK: - Recent Documents
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent")
                            .font(.headingS)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 20)

                        if recentDocuments.isEmpty {
                            Text("Nothing here yet. Add or scan\na document")
                                .font(.bodyL)
                                .foregroundColor(.textTertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recentDocuments.prefix(5).enumerated()), id: \.element.id) { index, document in
                                    RecentDocumentRow(document: document) {
                                        selectedDocument = document
                                    }

                                    if index < min(recentDocuments.count, 5) - 1 {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                            .background(Color.surfaceWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 20)
                        }
                    }
                    .opacity(recentAppear ? 1 : 0)

                    Spacer(minLength: 80)
                }
            }
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

    // MARK: - Data Loading

    private func loadRecentDocuments() {
        let allDocuments = DocumentFileManager.shared.loadMetadata()
        recentDocuments = allDocuments
            .filter { $0.fileExists }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            greetingAppear = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
            bannerAppear = true
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

#Preview {
    HomeView()
        .environmentObject(HomeRouter())
}
