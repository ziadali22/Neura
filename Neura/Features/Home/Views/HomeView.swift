import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: HomeRouter
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @StateObject private var updateChecker = AppUpdateChecker.shared
    @StateObject private var healthVM = HealthProfileViewModel()
    @StateObject private var docsViewModel = DocumentsListViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @ObservedObject private var activeSpaceManager = ActiveSpaceManager.shared
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
    @AppStorage(UserLocationStore.defaultsKey) private var userLocation = ""
    @AppStorage("hasSeenCalendarPromo") private var hasSeenCalendarPromo = false
    /// Shared with DashboardView — the calendar promo waits until the
    /// plus-button coach mark has been seen before it appears.
    @AppStorage("hasSeenDocumentCoachmark") private var hasSeenCoachmark = false
    @State private var showCalendarPromo = false
    /// Clock the next-appointment card is evaluated against. Advanced when the
    /// one-hour grace after an appointment elapses, and whenever Home reappears.
    @State private var appointmentClock = Date()
    @State private var editingAppointment: CalendarEntry?
    @Environment(\.scenePhase) private var scenePhase

    private var nextAppointment: HomeNextAppointment? {
        HomeNextAppointment.next(in: calendarViewModel.entries, at: appointmentClock)
    }

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
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Greeting + health card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(greeting)
                                .font(.displaySemi)
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                router.push(.calendar)
                            } label: {
                                GlassIconButton(size: 44) {
                                    Image("calendar-date")
                                        .renderingMode(.original)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityLabel(L10n.Calendar.title)
                        }
                        .overlay(alignment: .topTrailing) {
                            if showCalendarPromo {
                                CalendarPromoPopover(
                                    onOpen: {
                                        dismissCalendarPromo()
                                        router.push(.calendar)
                                    },
                                    onDismiss: { dismissCalendarPromo() }
                                )
                                .offset(x: 0, y: 48)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .opacity(greetingAppear ? 1 : 0)
                        .offset(y: greetingAppear ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: greetingAppear)
                        .zIndex(1)

                        // MARK: - Profile Cards
                        VStack(alignment: .leading, spacing: 16) {
                            SecureProfileCard(
                                name: healthVM.profile.generalData.fullName,
                                location: userLocation,
                                background: cardBackground,
                                onShareTap: {
                                    AnalyticsManager.shared.track(.shareHealthProfileTapped, properties: ["source": "home"])
                                    showShareSheet = true
                                },
                                onCustomizeTap: {
                                    AnalyticsManager.shared.track(.backgroundPickerOpened)
                                    showBackgroundPicker = true
                                },
                                onTap: {
                                    AnalyticsManager.shared.track(.secureProfileCardTapped)
                                    authenticateAndOpenProfile()
                                }
                            )
                            .scaleEffect(profileCardAppear ? 1 : 0.95)
                            .opacity(profileCardAppear ? 1 : 0)
                            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: profileCardAppear)

                            CompleteProfileCard(
                                generalData: healthVM.profile.generalData,
                                onTap: {
                                    AnalyticsManager.shared.track(.completeProfileCardTapped)
                                    router.push(.healthProfile)
                                }
                            )
                            .offset(y: completeCardAppear ? 0 : 30)
                            .opacity(completeCardAppear ? 1 : 0)
                            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: completeCardAppear)
                        }
                        .padding(.horizontal, 20)
                    }

                    // MARK: - Next appointment
                    if let nextAppointment {
                        NextAppointmentSection(
                            appointment: nextAppointment,
                            onTap: { editingAppointment = nextAppointment.entry },
                            onToggle: {
                                calendarViewModel.toggleCompletion(nextAppointment.entry, on: nextAppointment.occurrence)
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .task(id: nextAppointment.hideAt) {
                            await dismissAppointmentWhenDue(nextAppointment.hideAt)
                        }
                    }

                    // MARK: - Recent Documents
                    RecentDocumentsSection(
                        documents: recentDocuments,
                        onDocumentTap: { selectedDocument = $0 }
                    )
                    .opacity(recentAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: recentAppear)

                    Spacer(minLength: 80)
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: nextAppointment)
            }
            .scrollIndicators(.hidden)
            .background(Color.backgroundPrimary)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .healthProfile:
                    HealthProfileView()
                case .healthProfileDetail:
                    HealthProfileDetailView()
                case .calendar:
                    CalendarView()
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
                    .onAppear { AnalyticsManager.shared.track(.appUpdatePromptShown) }
            }
            .sheet(item: $editingAppointment) { entry in
                EntryEditorSheet(
                    existing: entry,
                    initialDate: entry.date,
                    documents: docsViewModel.spaceScopedDocuments,
                    onSave: { calendarViewModel.save($0) },
                    onDelete: { calendarViewModel.delete($0) },
                    onDeleteDocument: { docsViewModel.deleteDocument($0) },
                    onCreateDocument: { docsViewModel.registerAttachment($0) }
                )
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
                AnalyticsManager.shared.track(.homeViewed)
                appointmentClock = Date()
                loadRecentDocuments()
                Task { await updateChecker.checkForUpdate() }
                maybeShowCalendarPromo()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { appointmentClock = Date() }
            }
            .onChange(of: hasSeenCoachmark) { _, seen in
                // The coach mark just got dismissed — now surface the promo.
                if seen { maybeShowCalendarPromo() }
            }
            .onChange(of: router.path) {
                if router.path.isEmpty {
                    appointmentClock = Date()
                    healthVM.reload()
                    loadRecentDocuments()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .documentsRestored)) { _ in
                loadRecentDocuments()
            }
            .onReceive(NotificationCenter.default.publisher(for: .documentsChanged)) { _ in
                loadRecentDocuments()
            }
            .onChange(of: activeSpaceManager.currentSpaceID) { _, _ in
                loadRecentDocuments()
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthProfileRestored)) { _ in
                healthVM.reload()
            }
        }
    }

    // MARK: - Actions

    /// Drops the home appointment once its grace period ends, even if Home stays open.
    private func dismissAppointmentWhenDue(_ hideAt: Date) async {
        let delay = hideAt.timeIntervalSinceNow
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
        }
        appointmentClock = max(Date(), hideAt)
    }

    /// Shows the calendar promo once — but only after the plus-button coach
    /// mark has been seen, so the two onboarding hints don't overlap.
    private func maybeShowCalendarPromo() {
        guard hasSeenCoachmark, !hasSeenCalendarPromo, !showCalendarPromo else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.0)) {
            showCalendarPromo = true
        }
    }

    private func dismissCalendarPromo() {
        withAnimation(.easeOut(duration: 0.2)) { showCalendarPromo = false }
        hasSeenCalendarPromo = true
    }

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
        docsViewModel.loadDocuments()
        recentDocuments = docsViewModel.allFilesSorted
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
