# Mixpanel Events Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize Mixpanel event names into an `AnalyticsEvent` enum and add tracking to Home, Profile, Docs, Dashboard, and HealthProfile — the areas with zero or partial coverage today.

**Architecture:** One new file (`Core/Services/AnalyticsEvent.swift`) defines every event name as a `String`-backed enum case plus a small property-key enum. `AnalyticsManager` gains a `track(_ event: AnalyticsEvent, ...)` overload alongside its existing string-based one (kept for the one dynamically-built onboarding event name). All 9 existing call sites migrate to the enum with no behavior change. New call sites are added at the real UI/viewmodel locations identified by reading the actual source — no speculative APIs.

**Tech Stack:** Swift, SwiftUI, Mixpanel SDK (already integrated). No test target exists in this project (per `CLAUDE.md`) — verification is: project builds, then each changed screen/action is manually exercised once in the iOS Simulator.

**Privacy constraint (binding for every task below):** Never pass a document name, folder name, doctor name, note, tag, or `MedicalSpecialization` value as a Mixpanel property. Only `DocumentCategory` raw values (a small fixed enum), booleans, counts, and other closed enum-derived strings (tab name, action name, language code) are sent. See `docs/superpowers/specs/2026-07-09-mixpanel-events-expansion-design.md` for the full rationale.

---

### Task 1: Create the `AnalyticsEvent` enum and wire up `AnalyticsManager`

**Files:**
- Create: `Neura/Core/Services/AnalyticsEvent.swift`
- Modify: `Neura/Core/Services/AnalyticsManager.swift:41` (insert after the existing `track(_ event: String...)` method)

- [ ] **Step 1: Create `AnalyticsEvent.swift`**

```swift
import Foundation

/// Central registry of Mixpanel event names and property keys. Every event this
/// app sends should have a case here — raw string literals at call sites make
/// typos and duplicate names easy to miss as the event list grows.
enum AnalyticsEvent: String {
    // Existing events, migrated from raw string literals (names unchanged).
    case signUpCompleted = "sign_up_completed"
    case sessionStart = "session_start"
    case folderCreated = "folder_created"
    case documentSaved = "document_saved"
    case calendarEntryCreated = "calendar_entry_created"
    case calendarEntryUpdated = "calendar_entry_updated"
    case calendarEntryCompleted = "calendar_entry_completed"
    case subscriptionStarted = "subscription_started"
    case paywallViewed = "paywall_viewed"
    // NOTE: "onboarding_V{appVersion}_{screen}_completed" stays a dynamically
    // interpolated string at its call site (OnboardingViewModel.swift) — it is
    // not a fixed name, so it isn't represented here.

    // Home
    case homeViewed = "home_viewed"
    case shareHealthProfileTapped = "share_health_profile_tapped"
    case backgroundPickerOpened = "background_picker_opened"
    case secureProfileCardTapped = "secure_profile_card_tapped"
    case completeProfileCardTapped = "complete_profile_card_tapped"
    case emergencyCardTapped = "emergency_card_tapped"
    case appUpdatePromptShown = "app_update_prompt_shown"

    // Profile
    case profileViewed = "profile_viewed"
    case loggedOut = "logged_out"
    case accountDeleted = "account_deleted"
    case biometricToggleChanged = "biometric_toggle_changed"
    case feedbackSheetOpened = "feedback_sheet_opened"
    case languageChanged = "language_changed"
    case subscriptionScreenViewed = "subscription_screen_viewed"

    // Docs
    case docsViewed = "docs_viewed"
    case documentDeleted = "document_deleted"
    case documentsBulkDeleted = "documents_bulk_deleted"
    case addDocumentSheetOpened = "add_document_sheet_opened"
    case documentScanStarted = "document_scan_started"
    case categoryOpened = "category_opened"
    case folderOpened = "folder_opened"
    case documentShareTapped = "document_share_tapped"

    // Dashboard
    case tabSwitched = "tab_switched"
    case floatingMenuOpened = "floating_menu_opened"
    case floatingMenuActionSelected = "floating_menu_action_selected"

    // HealthProfile
    case healthProfileViewed = "health_profile_viewed"
    case healthProfileSaved = "health_profile_saved"
}

/// Property key constants, reused across events to keep key names consistent.
/// Not every event uses one of these — some (e.g. `document_saved`) keep their
/// pre-existing literal keys ("source", "method", "type"...) unchanged to avoid
/// touching working, already-shipped event schemas.
enum AnalyticsProperty: String {
    case source, category, count, tab, action, enabled, language
}
```

- [ ] **Step 2: Add the enum-based `track` overload to `AnalyticsManager`**

In `Neura/Core/Services/AnalyticsManager.swift`, insert immediately after the existing method (currently lines 37-41):

```swift
    /// Tracks an event using a centrally-defined name. Prefer this over the
    /// string overload below for any event whose name isn't dynamically built.
    func track(_ event: AnalyticsEvent, properties: [String: MixpanelType]? = nil) {
        track(event.rawValue, properties: properties)
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`. The new enum/overload aren't called yet, so this only proves the new file compiles cleanly.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/AnalyticsEvent.swift Neura/Core/Services/AnalyticsManager.swift
git commit -m "Add centralized AnalyticsEvent enum and enum-based track() overload"
```

---

### Task 2: Migrate the 9 existing call sites to `AnalyticsEvent`

No behavior change — only the event-name argument changes from a string literal to an enum case. Property dictionaries are untouched except the `folder_created` PHI fix.

**Files:**
- Modify: `Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift:204`, `:226`
- Modify: `Neura/Features/Dashboard/Views/DashboardView.swift:87`
- Modify: `Neura/Features/Documents/Views/DocsView.swift:115-118`
- Modify: `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift:439`
- Modify: `Neura/Features/Calendar/ViewModel/CalendarViewModel.swift:122-125`, `:142`
- Modify: `Neura/Core/Services/SubscriptionManager.swift:172-175`
- Modify: `Neura/Features/Paywall/PaywallView.swift:140`

- [ ] **Step 1: `OnboardingViewModel.swift` — sign-up events**

Line 204:
```swift
// old
AnalyticsManager.shared.track("sign_up_completed", properties: ["method": "apple"])
// new
AnalyticsManager.shared.track(.signUpCompleted, properties: ["method": "apple"])
```

Line 226:
```swift
// old
AnalyticsManager.shared.track("sign_up_completed", properties: ["method": "google"])
// new
AnalyticsManager.shared.track(.signUpCompleted, properties: ["method": "google"])
```

- [ ] **Step 2: `DashboardView.swift:87` — session start**

```swift
// old
AnalyticsManager.shared.track("session_start")
// new
AnalyticsManager.shared.track(.sessionStart)
```

- [ ] **Step 3: `DocsView.swift:115-118` — folder created, and fix the PHI leak**

```swift
// old
                AnalyticsManager.shared.track("folder_created", properties: [
                    "folder_name": trimmed,
                    "total_folders": folderStore.folders.count
                ])
// new
                AnalyticsManager.shared.track(.folderCreated, properties: [
                    "total_folders": folderStore.folders.count
                ])
```

- [ ] **Step 4: `DocumentsListViewModel.swift:439` — document saved**

```swift
// old
AnalyticsManager.shared.track("document_saved", properties: ["source": source])
// new
AnalyticsManager.shared.track(.documentSaved, properties: ["source": source])
```

- [ ] **Step 5: `CalendarViewModel.swift` — calendar entry events**

Lines 122-125:
```swift
// old
        AnalyticsManager.shared.track(
            isNew ? "calendar_entry_created" : "calendar_entry_updated",
            properties: ["type": entry.type.rawValue]
        )
// new
        AnalyticsManager.shared.track(
            isNew ? .calendarEntryCreated : .calendarEntryUpdated,
            properties: ["type": entry.type.rawValue]
        )
```

Line 142:
```swift
// old
AnalyticsManager.shared.track("calendar_entry_completed", properties: ["type": entry.type.rawValue])
// new
AnalyticsManager.shared.track(.calendarEntryCompleted, properties: ["type": entry.type.rawValue])
```

- [ ] **Step 6: `SubscriptionManager.swift:172-175` — subscription started**

```swift
// old
                    AnalyticsManager.shared.track("subscription_started", properties: [
                        "product_id": product.id,
                        "price": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
// new
                    AnalyticsManager.shared.track(.subscriptionStarted, properties: [
                        "product_id": product.id,
                        "price": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
```

- [ ] **Step 7: `PaywallView.swift:140` — paywall viewed**

```swift
// old
.onAppear { AnalyticsManager.shared.track("paywall_viewed") }
// new
.onAppear { AnalyticsManager.shared.track(.paywallViewed) }
```

- [ ] **Step 8: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Manually verify no regression**

Run the app in the simulator: complete/skip an onboarding step (or sign in), background→foreground the app once (session_start), create a calendar entry, create a folder in Docs (confirm no folder name property — inspect via a breakpoint or trust the diff), save a document, view the paywall. None of these should crash or behave differently than before.

- [ ] **Step 10: Commit**

```bash
git add Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift \
        Neura/Features/Dashboard/Views/DashboardView.swift \
        Neura/Features/Documents/Views/DocsView.swift \
        Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift \
        Neura/Features/Calendar/ViewModel/CalendarViewModel.swift \
        Neura/Core/Services/SubscriptionManager.swift \
        Neura/Features/Paywall/PaywallView.swift
git commit -m "Migrate existing Mixpanel call sites to AnalyticsEvent; drop folder_name PHI leak"
```

---

### Task 3: Home tab events

**Files:**
- Modify: `Neura/Features/Home/Views/HomeView.swift`

- [ ] **Step 1: `home_viewed` on appear (line 192)**

```swift
// old
            .onAppear {
                loadRecentDocuments()
                Task { await updateChecker.checkForUpdate() }
                maybeShowCalendarPromo()
            }
// new
            .onAppear {
                AnalyticsManager.shared.track(.homeViewed)
                loadRecentDocuments()
                Task { await updateChecker.checkForUpdate() }
                maybeShowCalendarPromo()
            }
```

- [ ] **Step 2: `share_health_profile_tapped`, `background_picker_opened`, `secure_profile_card_tapped` (lines 106-113, the `SecureProfileCard` init)**

```swift
// old
                        SecureProfileCard(
                            name: healthVM.profile.generalData.fullName,
                            location: UserDefaults.standard.string(forKey: "user_location") ?? "",
                            background: cardBackground,
                            onShareTap: { showShareSheet = true },
                            onCustomizeTap: { showBackgroundPicker = true },
                            onTap: { authenticateAndOpenProfile() }
                        )
// new
                        SecureProfileCard(
                            name: healthVM.profile.generalData.fullName,
                            location: UserDefaults.standard.string(forKey: "user_location") ?? "",
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
```

- [ ] **Step 3: `complete_profile_card_tapped` (lines 118-121, the `CompleteProfileCard` init)**

```swift
// old
                        CompleteProfileCard(
                            generalData: healthVM.profile.generalData,
                            onTap: { router.push(.healthProfile) }
                        )
// new
                        CompleteProfileCard(
                            generalData: healthVM.profile.generalData,
                            onTap: {
                                AnalyticsManager.shared.track(.completeProfileCardTapped)
                                router.push(.healthProfile)
                            }
                        )
```

- [ ] **Step 4: `emergency_card_tapped` (line 129)**

```swift
// old
                    EmergencyCardBanner { router.push(.emergencyCard) }
// new
                    EmergencyCardBanner {
                        AnalyticsManager.shared.track(.emergencyCardTapped)
                        router.push(.emergencyCard)
                    }
```

- [ ] **Step 5: `app_update_prompt_shown` (lines 173-177)**

```swift
// old
            .sheet(item: $updateChecker.availableUpdate) { update in
                AppUpdateSheet(update: update)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(32)
            }
// new
            .sheet(item: $updateChecker.availableUpdate) { update in
                AppUpdateSheet(update: update)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(32)
                    .onAppear { AnalyticsManager.shared.track(.appUpdatePromptShown) }
            }
```

- [ ] **Step 6: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Manually verify in the simulator**

Open the Home tab (fires `home_viewed`). Tap the share icon on the profile card (`share_health_profile_tapped`), dismiss, tap the customize/background icon (`background_picker_opened`), dismiss, tap the profile card itself (`secure_profile_card_tapped` — may trigger biometric prompt first, that's expected), tap the "Complete your profile" card (`complete_profile_card_tapped`), tap the emergency card banner (`emergency_card_tapped`). Confirm no crashes and each sheet/navigation still works exactly as before.

- [ ] **Step 8: Commit**

```bash
git add Neura/Features/Home/Views/HomeView.swift
git commit -m "Add Mixpanel tracking to Home tab actions"
```

---

### Task 4: Profile tab events

**Files:**
- Modify: `Neura/Features/Profile/Views/ProfileView.swift`
- Modify: `Neura/Features/Profile/Views/Components/LanguagePickerView.swift`

- [ ] **Step 1: `profile_viewed` on appear**

In `ProfileView.swift`, the `NavigationStack` closes right before `.fullScreenCover(isPresented: $showPaywall)` (around line 140-142). Add `.onAppear` there:

```swift
// old
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
// new
        }
        .onAppear { AnalyticsManager.shared.track(.profileViewed) }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
```

- [ ] **Step 2: `logged_out` in `handleLogOut()` (lines 241-246)**

```swift
// old
    func handleLogOut() {
        clearLocalUserData()
        // Sign out from Firebase — AuthService publishes isSignedIn=false,
        // which causes NeuraApp to switch back to OnboardingView.
        AuthService.shared.signOut()
    }
// new
    func handleLogOut() {
        AnalyticsManager.shared.track(.loggedOut)
        clearLocalUserData()
        // Sign out from Firebase — AuthService publishes isSignedIn=false,
        // which causes NeuraApp to switch back to OnboardingView.
        AuthService.shared.signOut()
    }
```

- [ ] **Step 3: `account_deleted` in `handleDeleteAccount()` (lines 248-268), only on success**

```swift
// old
                try await AuthService.shared.deleteAccount()
                clearLocalUserData()
                // deleteAccount() published currentUser = nil, so NeuraApp has already
                // swapped to OnboardingView; this view (and its overlay) tears down with it.
// new
                try await AuthService.shared.deleteAccount()
                AnalyticsManager.shared.track(.accountDeleted)
                clearLocalUserData()
                // deleteAccount() published currentUser = nil, so NeuraApp has already
                // swapped to OnboardingView; this view (and its overlay) tears down with it.
```

- [ ] **Step 4: `biometric_toggle_changed` in `handleBiometricToggle(_:)` (lines 270-279)**

```swift
// old
    func handleBiometricToggle(_ enabled: Bool) {
        guard biometricAuth.isBiometricAvailable else {
            showBiometricUnavailableAlert = true
            return
        }

        Task {
            _ = await biometricAuth.setBiometricLockEnabled(enabled)
        }
    }
// new
    func handleBiometricToggle(_ enabled: Bool) {
        guard biometricAuth.isBiometricAvailable else {
            showBiometricUnavailableAlert = true
            return
        }

        AnalyticsManager.shared.track(.biometricToggleChanged, properties: ["enabled": enabled])
        Task {
            _ = await biometricAuth.setBiometricLockEnabled(enabled)
        }
    }
```

- [ ] **Step 5: `feedback_sheet_opened` (lines 85-87)**

```swift
// old
                            SettingsRow(icon: "fav", title: L10n.Profile.feedback) {
                                showFeedback = true
                            }
// new
                            SettingsRow(icon: "fav", title: L10n.Profile.feedback) {
                                AnalyticsManager.shared.track(.feedbackSheetOpened)
                                showFeedback = true
                            }
```

- [ ] **Step 6: `subscription_screen_viewed` in `handleSubscriptionTap()` (lines 281-287)**

Only the Pro-user branch counts as "viewed the subscription screen" — the non-Pro branch shows the paywall, which already tracks `paywall_viewed` separately.

```swift
// old
    func handleSubscriptionTap() {
        if subscriptionManager.isPro {
            router.push(.subscription)
        } else {
            showPaywall = true
        }
    }
// new
    func handleSubscriptionTap() {
        if subscriptionManager.isPro {
            AnalyticsManager.shared.track(.subscriptionScreenViewed, properties: ["source": "profile"])
            router.push(.subscription)
        } else {
            showPaywall = true
        }
    }
```

- [ ] **Step 7: `language_changed` in `LanguagePickerView.swift` (lines 10-17)**

```swift
// old
                    Button {
                        // Do NOT wrap this in withAnimation: changing the language
                        // re-applies \.locale / \.layoutDirection to the whole app at the
                        // NeuraApp root, which animates an app-wide re-layout. Because the
                        // tab bar lives in a bottom safeAreaInset and is hidden while this
                        // picker (a pushed detail view) is on screen, that interrupted spring
                        // leaves the bar stuck shifted up after navigating back.
                        languageManager.setLanguage(language)
                    } label: {
// new
                    Button {
                        AnalyticsManager.shared.track(.languageChanged, properties: ["language": language.rawValue])
                        // Do NOT wrap this in withAnimation: changing the language
                        // re-applies \.locale / \.layoutDirection to the whole app at the
                        // NeuraApp root, which animates an app-wide re-layout. Because the
                        // tab bar lives in a bottom safeAreaInset and is hidden while this
                        // picker (a pushed detail view) is on screen, that interrupted spring
                        // leaves the bar stuck shifted up after navigating back.
                        languageManager.setLanguage(language)
                    } label: {
```

- [ ] **Step 8: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Manually verify in the simulator**

Open the Profile tab (`profile_viewed`). Toggle biometric lock on/off (`biometric_toggle_changed` x2), open Feedback (`feedback_sheet_opened`), open Language and tap a different language (`language_changed`) — confirm the app's language actually changes as before. If you have an active Pro subscription in this build, tap Subscription (`subscription_screen_viewed`); otherwise confirm it still opens the paywall. Do NOT actually complete log out / delete account against a real account unless using a disposable test account — reading the diff is sufficient confirmation for those two.

- [ ] **Step 10: Commit**

```bash
git add Neura/Features/Profile/Views/ProfileView.swift Neura/Features/Profile/Views/Components/LanguagePickerView.swift
git commit -m "Add Mixpanel tracking to Profile tab actions"
```

---

### Task 5: Docs tab events

**Files:**
- Modify: `Neura/Features/Documents/Views/DocsView.swift`
- Modify: `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`
- Modify: `Neura/Features/Documents/Views/Components/DocsFoldersGrid.swift`
- Modify: `Neura/Features/Documents/Views/Components/DocumentViewerView.swift`

- [ ] **Step 1: `docs_viewed` on appear — `DocsView.swift:124-131`**

```swift
// old
        .onAppear {
            viewModel.loadDocuments()
            if let action = coordinator.pendingAddAction {
                coordinator.pendingAddAction = nil
                handlePendingAction(action)
            }
            openPendingDocumentIfNeeded()
        }
// new
        .onAppear {
            AnalyticsManager.shared.track(.docsViewed)
            viewModel.loadDocuments()
            if let action = coordinator.pendingAddAction {
                coordinator.pendingAddAction = nil
                handlePendingAction(action)
            }
            openPendingDocumentIfNeeded()
        }
```

- [ ] **Step 2: `documents_bulk_deleted` — `DocsView.swift:353-360`**

Note: each document in the batch also fires `document_deleted` individually via `viewModel.deleteDocument(doc)` (Step 4 below) — that's intentional, it keeps the per-category breakdown working while this event gives you the aggregate count.

```swift
// old
    private func deleteSelectedDocuments() {
        let toDelete = viewModel.documents.filter { selectedDocuments.contains($0.id) }
        for doc in toDelete { viewModel.deleteDocument(doc) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDocuments.removeAll()
            isSelecting = false
        }
    }
// new
    private func deleteSelectedDocuments() {
        let toDelete = viewModel.documents.filter { selectedDocuments.contains($0.id) }
        AnalyticsManager.shared.track(.documentsBulkDeleted, properties: ["count": toDelete.count])
        for doc in toDelete { viewModel.deleteDocument(doc) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDocuments.removeAll()
            isSelecting = false
        }
    }
```

- [ ] **Step 3: `add_document_sheet_opened` — `DocumentsListViewModel.swift:249-256`**

```swift
// old
    func showAddOptions() {
        let sub = SubscriptionManager.shared
        guard sub.canUpload else {
            showPaywall = true
            return
        }
        showSourcePicker = true
    }
// new
    func showAddOptions() {
        let sub = SubscriptionManager.shared
        guard sub.canUpload else {
            showPaywall = true
            return
        }
        AnalyticsManager.shared.track(.addDocumentSheetOpened)
        showSourcePicker = true
    }
```

- [ ] **Step 4: `document_deleted` — `DocumentsListViewModel.swift:541-552`**

```swift
// old
    func deleteDocument(_ document: Document) {
        do {
            try fileManager.deleteDocument(document)
            documents.removeAll { $0.id == document.id }
            persistMetadata()
            DocumentExpiryReminderScheduler.shared.reschedule(for: documents)
            SyncQueueManager.shared.enqueueDelete(document.id)
            SubscriptionManager.shared.recordDeletion()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
// new
    func deleteDocument(_ document: Document) {
        do {
            try fileManager.deleteDocument(document)
            documents.removeAll { $0.id == document.id }
            persistMetadata()
            DocumentExpiryReminderScheduler.shared.reschedule(for: documents)
            SyncQueueManager.shared.enqueueDelete(document.id)
            SubscriptionManager.shared.recordDeletion()
            AnalyticsManager.shared.track(.documentDeleted, properties: ["category": document.category?.rawValue ?? "none"])
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
```

- [ ] **Step 5: `document_scan_started` — `DocumentsListViewModel.swift:258-264`**

```swift
// old
    func startScanning() {
        guard ensureCanUpload() else { return }
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showScanner = true
        }
    }
// new
    func startScanning() {
        guard ensureCanUpload() else { return }
        AnalyticsManager.shared.track(.documentScanStarted)
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showScanner = true
        }
    }
```

- [ ] **Step 6: `category_opened` and `folder_opened` — `DocsFoldersGrid.swift`**

`NavigationLink(value:)` has no action closure, so use `.simultaneousGesture` to observe the tap without interfering with navigation.

Lines 45-53:
```swift
// old
            ForEach(DocumentCategory.allCases) { category in
                NavigationLink(value: category) {
                    CategoryFolderGridCard(
                        category: category,
                        count: (docsByCategory[category] ?? []).count
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
// new
            ForEach(DocumentCategory.allCases) { category in
                NavigationLink(value: category) {
                    CategoryFolderGridCard(
                        category: category,
                        count: (docsByCategory[category] ?? []).count
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    AnalyticsManager.shared.track(.categoryOpened, properties: ["category": category.rawValue])
                })
            }
```

Lines 56-64 (only the `NavigationLink` + `.buttonStyle` lines change; `.contextMenu` and everything after stay as-is):
```swift
// old
                NavigationLink(value: folder) {
                    CustomFolderGridCard(folder: folder, count: count)
                }
                .buttonStyle(ScaleButtonStyle())
                .contextMenu {
// new
                NavigationLink(value: folder) {
                    CustomFolderGridCard(folder: folder, count: count)
                }
                .buttonStyle(ScaleButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    AnalyticsManager.shared.track(.folderOpened)
                })
                .contextMenu {
```

- [ ] **Step 7: `document_share_tapped` — `DocumentViewerView.swift:438-450`**

```swift
// old
    func shareDocument() {
        guard document.fileExists else { return }

        let activityVC = UIActivityViewController(
            activityItems: [document.fileURL],
            applicationActivities: nil
        )
// new
    func shareDocument() {
        guard document.fileExists else { return }

        AnalyticsManager.shared.track(.documentShareTapped, properties: ["category": document.category?.rawValue ?? "none"])

        let activityVC = UIActivityViewController(
            activityItems: [document.fileURL],
            applicationActivities: nil
        )
```

- [ ] **Step 8: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Manually verify in the simulator**

Open Docs (`docs_viewed`). Tap a category card (`category_opened`) and a custom folder card if one exists (`folder_opened`) — confirm navigation into each still works. Tap the "+" to add a document and start a scan (`add_document_sheet_opened`, `document_scan_started`) — cancel the scanner, no need to complete it. Open a document's three-dot menu and tap Share (`document_share_tapped`) — confirm the iOS share sheet still appears. Select 2+ documents and delete them (`documents_bulk_deleted` + one `document_deleted` per doc) — confirm the documents are actually removed as before.

- [ ] **Step 10: Commit**

```bash
git add Neura/Features/Documents/Views/DocsView.swift \
        Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift \
        Neura/Features/Documents/Views/Components/DocsFoldersGrid.swift \
        Neura/Features/Documents/Views/Components/DocumentViewerView.swift
git commit -m "Add Mixpanel tracking to Docs tab actions"
```

---

### Task 6: Dashboard events (tab switch, floating add-menu)

**Files:**
- Modify: `Neura/Features/Dashboard/Views/Components/CustomTabBar.swift`

`FloatingDocumentMenu.swift` is confirmed dead code (never instantiated outside its own `#Preview` — verified via `grep -rn "FloatingDocumentMenu(" Neura --include="*.swift"` returning only its own file). It is NOT touched by this task.

- [ ] **Step 1: `tab_switched` — `TabSegmentedControl.segment(_:)`, lines 207-214**

```swift
// old
    private func segment(_ tab: AppCoordinator.Tab) -> some View {
        let selected = tab == selectedTab
        return Button {
            guard !selected else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
// new
    private func segment(_ tab: AppCoordinator.Tab) -> some View {
        let selected = tab == selectedTab
        return Button {
            guard !selected else { return }
            AnalyticsManager.shared.track(.tabSwitched, properties: ["tab": tab.label.lowercased()])
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
```

- [ ] **Step 2: `floating_menu_opened` — `fab`, lines 153-172**

Track only the actual open transition (guard `!isMenuOpen` before the toggle), not every FAB tap (which also closes the menu).

```swift
// old
    private var fab: some View {
        Button {
            HapticManager.medium()
            if canUpload {
                isMenuOpen.toggle()
            } else {
                onPaywallNeeded()
            }
        } label: {
// new
    private var fab: some View {
        Button {
            HapticManager.medium()
            if canUpload {
                if !isMenuOpen {
                    AnalyticsManager.shared.track(.floatingMenuOpened)
                }
                isMenuOpen.toggle()
            } else {
                onPaywallNeeded()
            }
        } label: {
```

- [ ] **Step 3: `floating_menu_action_selected` — `fire(_:)`, lines 178-184**

```swift
// old
    private func fire(_ action: AppCoordinator.AddDocumentAction) {
        HapticManager.medium()
        isMenuOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onAction(action)
        }
    }
// new
    private func fire(_ action: AppCoordinator.AddDocumentAction) {
        HapticManager.medium()
        AnalyticsManager.shared.track(.floatingMenuActionSelected, properties: ["action": String(describing: action)])
        isMenuOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onAction(action)
        }
    }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Manually verify in the simulator**

Switch between Profile/Home/Docs tabs (`tab_switched` x2+, confirm no event when tapping the already-selected tab). Tap the "+" FAB to open the add-document menu (`floating_menu_opened`), tap "Scan Document" (`floating_menu_action_selected` with `action: "scan"`) — confirm the scanner still opens.

- [ ] **Step 6: Commit**

```bash
git add Neura/Features/Dashboard/Views/Components/CustomTabBar.swift
git commit -m "Add Mixpanel tracking to Dashboard tab switch and add-menu"
```

---

### Task 7: HealthProfile events

**Files:**
- Modify: `Neura/Features/HealthProfile/Views/HealthProfileDetailView.swift`
- Modify: `Neura/Features/HealthProfile/ViewModel/HealthProfileViewModel.swift`

- [ ] **Step 1: `health_profile_viewed` — `HealthProfileDetailView.swift`, in the view's modifier chain (around line 30)**

```swift
// old
        .background(Color.backgroundPrimary)
        .overlay(alignment: .bottom) {
// new
        .background(Color.backgroundPrimary)
        .onAppear { AnalyticsManager.shared.track(.healthProfileViewed) }
        .overlay(alignment: .bottom) {
```

- [ ] **Step 2: `health_profile_saved` — `HealthProfileViewModel.swift:371-378`, the single `save()` chokepoint every mutation already funnels through**

```swift
// old
    private func save() {
        profile.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        SyncQueueManager.shared.enqueueProfileUpload(profile)
        updateNotifications()
    }
// new
    private func save() {
        profile.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        SyncQueueManager.shared.enqueueProfileUpload(profile)
        updateNotifications()
        AnalyticsManager.shared.track(.healthProfileSaved)
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manually verify in the simulator**

From Home, tap the Secure Profile Card and authenticate if prompted to reach `HealthProfileDetailView` (`health_profile_viewed`). Edit any field in the health profile and confirm it saves (`health_profile_saved`) and the change persists after backgrounding/reopening the app.

- [ ] **Step 5: Commit**

```bash
git add Neura/Features/HealthProfile/Views/HealthProfileDetailView.swift Neura/Features/HealthProfile/ViewModel/HealthProfileViewModel.swift
git commit -m "Add Mixpanel tracking to HealthProfile view and save"
```

---

## Final check

After all 7 tasks: grep the diff for any of `doctorName`, `notes`, `tags`, `folder_name`, `folder.name`, `document.name`, `specialization` inside a `track(...)` call — none should appear. Then do one full manual pass through Home → Profile → Docs → Dashboard → HealthProfile in the simulator to confirm nothing regressed.
