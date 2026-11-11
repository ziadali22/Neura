# Profile Email Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an email field to the Profile screen that, when saved, persists locally and sends the email plus the user's current subscription status to Mixpanel for marketing-list building.

**Architecture:** A new self-contained `EmailCaptureRow` SwiftUI view (owns its own text/validation state, following the existing `BiometricLockRow` styling pattern) is dropped into `ProfileView`'s "Profile" section. On save it hands the parent a trimmed, already-valid email string; `ProfileView` persists it to `UserDefaults` and calls a new `AnalyticsManager.setUserEmail(_:isSubscribed:)` method. No new ViewModel is introduced — `ProfileView` has none today and handles its other actions (biometric toggle, log out, delete account) the same way, directly in a private extension.

**Tech Stack:** SwiftUI, Mixpanel SDK (`people.set`, `track`), `UserDefaults`, existing `L10n` codegen-free string helpers.

## Global Constraints

- Email field is visible to **all** users, not gated on Pro status.
- Persist the email as a plain string in `UserDefaults` under key `neura_user_email` (no JSON encoding needed — matches how `neura_biometric_lock_enabled` etc. are stored).
- Mixpanel: set the reserved `$email` People property **and** an `is_subscribed: Bool` property on the People profile, then fire a raw-string `email_submitted` event with `is_subscribed` as an event property too.
- `isSubscribed` comes from `SubscriptionManager.shared.isPro` (`ProfileView` already holds this as `@StateObject`).
- Use a raw string for the `track()` call (`"email_submitted"`), consistent with every other existing call site — the `AnalyticsEvent` enum from the separate, not-yet-implemented Mixpanel expansion spec is out of scope here.
- Client-side validation only: `^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$` (case-insensitive) — the exact pattern already used in `FeedbackViewModel.isEmailValid`.
- No test target exists in this project (per `CLAUDE.md`) — verification is manual: build succeeds, exercise the flow in the simulator.
- New `L10n.Profile` strings (`email`, `emailPlaceholder`, `emailInvalid`) must be added to all three locale files: `en`, `ar`, `ro`.
- `neura_user_email` must be added to the keys cleared in `ProfileView.clearLocalUserData()` on logout/delete-account.

---

### Task 1: Add L10n strings for the email field

**Files:**
- Modify: `Neura/Core/L10n/L10n.swift:687-691`
- Modify: `Neura/Core/L10n/en.lproj/Localizable.strings:494-495`
- Modify: `Neura/Core/L10n/ar.lproj/Localizable.strings:489-490`
- Modify: `Neura/Core/L10n/ro.lproj/Localizable.strings:489-490`

**Interfaces:**
- Produces: `L10n.Profile.email`, `L10n.Profile.emailPlaceholder`, `L10n.Profile.emailInvalid` (all `String`), consumed by Task 3's `EmailCaptureRow`.

- [ ] **Step 1: Add the three new keys to `L10n.swift`**

In `Neura/Core/L10n/L10n.swift`, inside `enum Profile`, find:

```swift
        static var healthProfile: String { "profile.healthProfile".l10n() }
        static var subscription: String { "profile.subscription".l10n() }
        static var security: String { "profile.security".l10n() }
        static var language: String { "profile.language".l10n() }
        static var feedback: String { "profile.feedback".l10n() }
```

Replace with:

```swift
        static var healthProfile: String { "profile.healthProfile".l10n() }
        static var subscription: String { "profile.subscription".l10n() }
        static var security: String { "profile.security".l10n() }
        static var language: String { "profile.language".l10n() }
        static var email: String { "profile.email".l10n() }
        static var emailPlaceholder: String { "profile.emailPlaceholder".l10n() }
        static var emailInvalid: String { "profile.emailInvalid".l10n() }
        static var feedback: String { "profile.feedback".l10n() }
```

- [ ] **Step 2: Add English strings**

In `Neura/Core/L10n/en.lproj/Localizable.strings`, find:

```
"profile.language" = "Language";
"profile.feedback" = "Feedback";
```

Replace with:

```
"profile.language" = "Language";
"profile.email" = "Email";
"profile.emailPlaceholder" = "your@email.com";
"profile.emailInvalid" = "Enter a valid email address";
"profile.feedback" = "Feedback";
```

- [ ] **Step 3: Add Arabic strings**

In `Neura/Core/L10n/ar.lproj/Localizable.strings`, find:

```
"profile.language" = "اللغة";
"profile.feedback" = "ملاحظات";
```

Replace with:

```
"profile.language" = "اللغة";
"profile.email" = "البريد الإلكتروني";
"profile.emailPlaceholder" = "your@email.com";
"profile.emailInvalid" = "أدخل بريدًا إلكترونيًا صالحًا";
"profile.feedback" = "ملاحظات";
```

- [ ] **Step 4: Add Romanian strings**

In `Neura/Core/L10n/ro.lproj/Localizable.strings`, find:

```
"profile.language" = "Limbă";
"profile.feedback" = "Feedback";
```

Replace with:

```
"profile.language" = "Limbă";
"profile.email" = "E-mail";
"profile.emailPlaceholder" = "your@email.com";
"profile.emailInvalid" = "Introduceți o adresă de e-mail validă";
"profile.feedback" = "Feedback";
```

- [ ] **Step 5: Verify the build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Neura/Core/L10n/L10n.swift Neura/Core/L10n/en.lproj/Localizable.strings Neura/Core/L10n/ar.lproj/Localizable.strings Neura/Core/L10n/ro.lproj/Localizable.strings
git commit -m "Add L10n strings for profile email field"
```

---

### Task 2: Add `AnalyticsManager.setUserEmail(_:isSubscribed:)`

**Files:**
- Modify: `Neura/Core/Services/AnalyticsManager.swift:43-47`

**Interfaces:**
- Consumes: existing `private var isInitialized: Bool`, existing `func track(_ event: String, properties: [String: MixpanelType]? = nil)`.
- Produces: `func setUserEmail(_ email: String, isSubscribed: Bool)`, consumed by Task 4's `ProfileView.handleEmailSave(_:)`.

- [ ] **Step 1: Add the method**

In `Neura/Core/Services/AnalyticsManager.swift`, find:

```swift
    /// Associates subsequent events with a stable user identifier (e.g. after sign-in).
    func identify(_ distinctId: String) {
        guard isInitialized else { return }
        Mixpanel.mainInstance().identify(distinctId: distinctId)
    }
```

Replace with:

```swift
    /// Associates subsequent events with a stable user identifier (e.g. after sign-in).
    func identify(_ distinctId: String) {
        guard isInitialized else { return }
        Mixpanel.mainInstance().identify(distinctId: distinctId)
    }

    /// Sets the user's email on their Mixpanel People profile (via the reserved
    /// `$email` property) plus their current subscription status, and fires an
    /// `email_submitted` event carrying the same status. No-ops if analytics isn't
    /// initialized yet.
    func setUserEmail(_ email: String, isSubscribed: Bool) {
        guard isInitialized else { return }
        Mixpanel.mainInstance().people.set(properties: [
            "$email": email,
            "is_subscribed": isSubscribed
        ])
        track("email_submitted", properties: ["is_subscribed": isSubscribed])
    }
```

- [ ] **Step 2: Verify the build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/Services/AnalyticsManager.swift
git commit -m "Add setUserEmail to AnalyticsManager for subscriber email capture"
```

---

### Task 3: Create `EmailCaptureRow` component

**Files:**
- Create: `Neura/Features/Profile/Views/Components/EmailCaptureRow.swift`

**Interfaces:**
- Consumes: `L10n.Profile.emailPlaceholder`, `L10n.Profile.emailInvalid` (Task 1), `Color.textPrimary`/`.textTertiary`/`.surfaceWhite`/`.accent` (existing design tokens), `Font.statLabel`/`.captionS` (existing typography tokens).
- Produces: `EmailCaptureRow(initialEmail: String, onSave: @escaping (String) -> Void)` — a SwiftUI `View`. `onSave` is called with an already-trimmed, already-validated email string, only when it differs from `initialEmail` (or the last saved value). Consumed by Task 4's `ProfileView`.

- [ ] **Step 1: Write the component**

Create `Neura/Features/Profile/Views/Components/EmailCaptureRow.swift`:

```swift
import SwiftUI

struct EmailCaptureRow: View {
    let onSave: (String) -> Void

    @State private var email: String
    @State private var savedEmail: String
    @FocusState private var isFocused: Bool
    @State private var showError = false

    init(initialEmail: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _email = State(initialValue: initialEmail)
        _savedEmail = State(initialValue: initialEmail)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidFormat: Bool {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return trimmedEmail.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private var hasChanges: Bool { trimmedEmail != savedEmail }
    private var canSave: Bool { isValidFormat && hasChanges }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 24, height: 24)

                TextField(L10n.Profile.emailPlaceholder, text: $email)
                    .font(.statLabel)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .onChange(of: email) { _, _ in showError = false }

                Spacer()

                Button {
                    isFocused = false
                    guard hasChanges else { return }
                    guard isValidFormat else {
                        showError = true
                        return
                    }
                    showError = false
                    savedEmail = trimmedEmail
                    onSave(trimmedEmail)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(canSave ? Color.accent : Color.textTertiary)
                }
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)

            if showError {
                Text(L10n.Profile.emailInvalid)
                    .font(.captionS)
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 4)
            }
        }
    }
}

#Preview {
    VStack(spacing: 11) {
        EmailCaptureRow(initialEmail: "") { email in
            print("saved: \(email)")
        }
        EmailCaptureRow(initialEmail: "existing@example.com") { email in
            print("saved: \(email)")
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
```

- [ ] **Step 2: Verify the build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **` (the new file is auto-detected via the project's filesystem sync, per `CLAUDE.md`)

- [ ] **Step 3: Manually verify the two preview states**

Open `Neura/Features/Profile/Views/Components/EmailCaptureRow.swift` in Xcode, open the canvas preview (or run it via `#Preview` in the simulator). Confirm:
- The empty row's checkmark button is greyed out (disabled) until you type a valid-looking email.
- The pre-filled row's checkmark button starts greyed out (disabled, since `savedEmail == email`), and re-enables once you edit the text.
- Typing an invalid string (e.g. `abc`) and tapping save shows the red inline error text; the button never fires `onSave`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Profile/Views/Components/EmailCaptureRow.swift
git commit -m "Add EmailCaptureRow component"
```

---

### Task 4: Wire `EmailCaptureRow` into `ProfileView`

**Files:**
- Modify: `Neura/Features/Profile/Views/ProfileView.swift:18-21` (add persistence key)
- Modify: `Neura/Features/Profile/Views/ProfileView.swift:53-63` (add row to Profile section)
- Modify: `Neura/Features/Profile/Views/ProfileView.swift:238-303` (add save handler + clear key)

**Interfaces:**
- Consumes: `EmailCaptureRow(initialEmail:onSave:)` (Task 3), `AnalyticsManager.shared.setUserEmail(_:isSubscribed:)` (Task 2), `subscriptionManager.isPro` (existing `@StateObject`, `SubscriptionManager.swift:34`).
- Produces: nothing consumed elsewhere — this is the top of the call chain.

- [ ] **Step 1: Add the persistence key constant**

In `Neura/Features/Profile/Views/ProfileView.swift`, find:

```swift
    // Legal links, reachable by all users (incl. free tier) outside the paywall (App Review 5.1.1 / 5.1.2).
    private static let privacyURL = URL(string: "https://myneura.org/privacy")!
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
```

Replace with:

```swift
    // Legal links, reachable by all users (incl. free tier) outside the paywall (App Review 5.1.1 / 5.1.2).
    private static let privacyURL = URL(string: "https://myneura.org/privacy")!
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let userEmailKey = "neura_user_email"
```

- [ ] **Step 2: Add the row to the Profile section**

In `Neura/Features/Profile/Views/ProfileView.swift`, find:

```swift
                        // Profile section
                        ProfileSectionHeader(title: L10n.Profile.Section.profile)
                        VStack(spacing: 11) {
                            SettingsRow(icon: "profile", title: L10n.Profile.healthProfile) {
                                router.push(.healthProfile)
                            }
                            SettingsRow(icon: "sub", title: L10n.Profile.subscription) {
                                handleSubscriptionTap()
                            }
                        }
                        .padding(.bottom, 24)
```

Replace with:

```swift
                        // Profile section
                        ProfileSectionHeader(title: L10n.Profile.Section.profile)
                        VStack(spacing: 11) {
                            EmailCaptureRow(
                                initialEmail: UserDefaults.standard.string(forKey: Self.userEmailKey) ?? ""
                            ) { email in
                                handleEmailSave(email)
                            }
                            SettingsRow(icon: "profile", title: L10n.Profile.healthProfile) {
                                router.push(.healthProfile)
                            }
                            SettingsRow(icon: "sub", title: L10n.Profile.subscription) {
                                handleSubscriptionTap()
                            }
                        }
                        .padding(.bottom, 24)
```

- [ ] **Step 3: Add the save handler**

In `Neura/Features/Profile/Views/ProfileView.swift`, find:

```swift
    func handleSubscriptionTap() {
        if subscriptionManager.isPro {
            router.push(.subscription)
        } else {
            showPaywall = true
        }
    }
```

Replace with:

```swift
    func handleSubscriptionTap() {
        if subscriptionManager.isPro {
            router.push(.subscription)
        } else {
            showPaywall = true
        }
    }

    func handleEmailSave(_ email: String) {
        UserDefaults.standard.set(email, forKey: Self.userEmailKey)
        AnalyticsManager.shared.setUserEmail(email, isSubscribed: subscriptionManager.isPro)
    }
```

- [ ] **Step 4: Clear the key on logout/delete**

In `Neura/Features/Profile/Views/ProfileView.swift`, find:

```swift
    func clearLocalUserData() {
        let keys = [
            "health_profile_data",
            "hasCompletedOnboarding",
            "user_location",
            "onboarding_medical_areas",
            "neura_biometric_lock_enabled",
            "neura_document_upload_count",
            "neura_share_count",
            "neura_is_pro"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        try? DocumentFileManager.shared.deleteAllLocalDocuments()
    }
```

Replace with:

```swift
    func clearLocalUserData() {
        let keys = [
            "health_profile_data",
            "hasCompletedOnboarding",
            "user_location",
            "onboarding_medical_areas",
            "neura_biometric_lock_enabled",
            "neura_document_upload_count",
            "neura_share_count",
            "neura_is_pro",
            Self.userEmailKey
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        try? DocumentFileManager.shared.deleteAllLocalDocuments()
    }
```

- [ ] **Step 5: Verify the build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manually verify the full flow in the simulator**

Run the app in the iPhone 16 simulator (Profile tab):
1. Type an invalid string (e.g. `notanemail`) into the new email row and tap save — confirm the inline red error appears and nothing is persisted (force-quit and relaunch the app; the field should be empty again).
2. Type a valid email (e.g. `test@example.com`) and tap save — confirm the checkmark briefly re-disables (no more unsaved changes) and no error shows.
3. Force-quit and relaunch the app, navigate to Profile — confirm the email row is pre-filled with `test@example.com`.
4. Edit the email to a different valid address and save again — confirm it persists (relaunch to verify).
5. Log out (Account section → Log Out) or delete the account, sign back in, and confirm the email field is empty again (key was cleared).
6. With Mixpanel Live View open in the dashboard (or by temporarily adding a `print` in `setUserEmail` if Live View isn't accessible), confirm the `email_submitted` event fires with `is_subscribed` set correctly for both a free and a Pro-simulated account (`SubscriptionManager.shared` can be toggled via existing debug/test affordances if the project has one, otherwise verify the `isSubscribed` value passed matches `subscriptionManager.isPro` by inspection).

- [ ] **Step 7: Commit**

```bash
git add Neura/Features/Profile/Views/ProfileView.swift
git commit -m "Wire EmailCaptureRow into ProfileView with Mixpanel tracking"
```
