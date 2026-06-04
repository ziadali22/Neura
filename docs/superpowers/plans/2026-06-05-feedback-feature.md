# Feedback Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a feedback form (required validated email + required message) that writes submissions to a top-level Firestore `feedback` collection, reachable from the existing Profile → Feedback row.

**Architecture:** MVVM + service-layer, matching the project. `FeedbackView` (sheet) ⇄ `FeedbackViewModel` (`@MainActor`, validation + state machine) → `FeedbackService` (`actor`, plain Firestore write). Localized across en/ar/ro. Firestore rules gain an append-only `feedback` collection.

**Tech Stack:** SwiftUI, Firebase SDK (`FirebaseFirestore`, `FirebaseAuth`), `L10n_swift`.

> **Note on testing:** This Xcode project has **no test target** (per CLAUDE.md). "Verification" steps therefore use a compile check (`xcodebuild ... build`) and manual runtime checks, not unit tests. The build command (run from the repo root) is:
>
> ```bash
> xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
> ```
>
> Expected on success: `** BUILD SUCCEEDED **`.

---

### Task 1: Add localization keys

**Files:**
- Modify: `Neura/Core/L10n/L10n.swift` (Profile enum, ~line 514)
- Modify: `Neura/Core/L10n/en.lproj/Localizable.strings` (after `profile.feedback` line)
- Modify: `Neura/Core/L10n/ar.lproj/Localizable.strings` (after `profile.feedback` line)
- Modify: `Neura/Core/L10n/ro.lproj/Localizable.strings` (after `profile.feedback` line)

- [ ] **Step 1: Add the nested `Feedback` enum to `L10n.swift`**

In `Neura/Core/L10n/L10n.swift`, inside `enum Profile { ... }`, immediately after the line `static var feedback: String { "profile.feedback".l10n() }`, add:

```swift
        enum Feedback {
            static var title: String { "profile.feedback.title".l10n() }
            static var emailLabel: String { "profile.feedback.emailLabel".l10n() }
            static var emailPlaceholder: String { "profile.feedback.emailPlaceholder".l10n() }
            static var messageLabel: String { "profile.feedback.messageLabel".l10n() }
            static var messagePlaceholder: String { "profile.feedback.messagePlaceholder".l10n() }
            static var submit: String { "profile.feedback.submit".l10n() }
            static var errorMessage: String { "profile.feedback.errorMessage".l10n() }
        }
```

(The existing `static var feedback` — the row label — is unchanged. The new keys are distinct, namespaced strings.)

- [ ] **Step 2: Add English strings**

In `Neura/Core/L10n/en.lproj/Localizable.strings`, immediately after the line `"profile.feedback" = "Feedback";`, add:

```
"profile.feedback.title" = "Send Feedback";
"profile.feedback.emailLabel" = "Email";
"profile.feedback.emailPlaceholder" = "your@email.com";
"profile.feedback.messageLabel" = "Your feedback";
"profile.feedback.messagePlaceholder" = "Tell us what you think about the app…";
"profile.feedback.submit" = "Send";
"profile.feedback.errorMessage" = "Something went wrong. Please try again.";
```

- [ ] **Step 3: Add Arabic strings**

In `Neura/Core/L10n/ar.lproj/Localizable.strings`, immediately after the line `"profile.feedback" = "ملاحظات";`, add:

```
"profile.feedback.title" = "إرسال ملاحظات";
"profile.feedback.emailLabel" = "البريد الإلكتروني";
"profile.feedback.emailPlaceholder" = "your@email.com";
"profile.feedback.messageLabel" = "ملاحظاتك";
"profile.feedback.messagePlaceholder" = "أخبرنا برأيك في التطبيق…";
"profile.feedback.submit" = "إرسال";
"profile.feedback.errorMessage" = "حدث خطأ ما. يرجى المحاولة مرة أخرى.";
```

- [ ] **Step 4: Add Romanian strings**

In `Neura/Core/L10n/ro.lproj/Localizable.strings`, immediately after the line `"profile.feedback" = "Feedback";`, add:

```
"profile.feedback.title" = "Trimite feedback";
"profile.feedback.emailLabel" = "E-mail";
"profile.feedback.emailPlaceholder" = "your@email.com";
"profile.feedback.messageLabel" = "Feedback-ul tău";
"profile.feedback.messagePlaceholder" = "Spune-ne ce crezi despre aplicație…";
"profile.feedback.submit" = "Trimite";
"profile.feedback.errorMessage" = "Ceva n-a mers bine. Încearcă din nou.";
```

- [ ] **Step 5: Commit**

```bash
git add Neura/Core/L10n/
git commit -m "feat(feedback): add localization keys for feedback form"
```

---

### Task 2: Create `FeedbackService`

**Files:**
- Create: `Neura/Core/Services/FeedbackService.swift`

- [ ] **Step 1: Write the service**

Create `Neura/Core/Services/FeedbackService.swift`:

```swift
import Foundation
import UIKit
import FirebaseFirestore

// MARK: - Feedback Service

/// Writes user feedback to the top-level `feedback` collection.
/// Plain (unencrypted), append-only write — feedback is not sensitive health data.
actor FeedbackService {
    static let shared = FeedbackService()

    private init() {}

    /// Submits one feedback entry. `uid` is attached only when a user is signed in.
    func submit(email: String, message: String, uid: String?) async throws {
        var data: [String: Any] = [
            "email": email,
            "message": message,
            "createdAt": FieldValue.serverTimestamp(),
            "appVersion": Self.appVersion,
            "platform": Self.platform,
            "locale": UserDefaults.standard.string(forKey: "app_language") ?? "en"
        ]
        if let uid {
            data["uid"] = uid
        }

        try await Firestore.firestore()
            .collection("feedback")
            .addDocument(data: data)
    }

    // MARK: - Metadata

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static var platform: String {
        "iOS \(UIDevice.current.systemVersion)"
    }
}
```

Notes for the implementer:
- Locale is read from `UserDefaults` key `"app_language"` (the key `LanguageManager` writes) rather than touching the `@Observable` `LanguageManager` from a background actor — `UserDefaults` is thread-safe, the `@Observable` is not.
- `Bundle` and `UIDevice.current.systemVersion` are safe to read off the main thread.

- [ ] **Step 2: Verify it compiles**

Run the build command from the plan header.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/Services/FeedbackService.swift
git commit -m "feat(feedback): add FeedbackService for Firestore writes"
```

---

### Task 3: Create `FeedbackViewModel`

**Files:**
- Create: `Neura/Features/Feedback/ViewModel/FeedbackViewModel.swift`

- [ ] **Step 1: Write the view model**

Create `Neura/Features/Feedback/ViewModel/FeedbackViewModel.swift`:

```swift
import Foundation
import SwiftUI

// MARK: - Feedback View Model

@MainActor
final class FeedbackViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case submitting
        case success
        case error(String)
    }

    @Published var email: String = ""
    @Published var message: String = ""
    @Published private(set) var state: State = .idle

    private let service: FeedbackService

    init(service: FeedbackService = .shared) {
        self.service = service
    }

    // MARK: - Validation

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    var isMessageValid: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var isValid: Bool { isEmailValid && isMessageValid }

    var isSubmitting: Bool { state == .submitting }

    // MARK: - Submit

    func submit() async {
        guard isValid, !isSubmitting else { return }
        state = .submitting

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = AuthService.shared.currentUser?.uid

        do {
            try await service.submit(email: trimmedEmail, message: trimmedMessage, uid: uid)
            state = .success
            HapticManager.success()
        } catch {
            state = .error(L10n.Profile.Feedback.errorMessage)
            HapticManager.error()
        }
    }
}
```

Notes:
- `AuthService.shared` is `@MainActor`; reading `currentUser?.uid` here is safe.
- Depends on `L10n.Profile.Feedback.errorMessage` (Task 1) and `FeedbackService` (Task 2).

- [ ] **Step 2: Verify it compiles**

Run the build command from the plan header.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Features/Feedback/ViewModel/FeedbackViewModel.swift
git commit -m "feat(feedback): add FeedbackViewModel with validation and state machine"
```

---

### Task 4: Create `FeedbackView`

**Files:**
- Create: `Neura/Features/Feedback/Views/FeedbackView.swift`

- [ ] **Step 1: Write the view**

Create `Neura/Features/Feedback/Views/FeedbackView.swift`:

```swift
import SwiftUI

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedbackViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, message
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    fieldGroup(
                        label: L10n.Profile.Feedback.emailLabel,
                        content: emailField
                    )

                    fieldGroup(
                        label: L10n.Profile.Feedback.messageLabel,
                        content: messageField
                    )

                    if case let .error(message) = viewModel.state {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }

                    submitButton
                }
                .padding(20)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(L10n.Profile.Feedback.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                guard newState == .success else { return }
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Subviews

private extension FeedbackView {

    func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
            content()
        }
    }

    var emailField: some View {
        TextField(L10n.Profile.Feedback.emailPlaceholder, text: $viewModel.email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .email)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .cornerRadius(14)
    }

    var messageField: some View {
        TextField(
            L10n.Profile.Feedback.messagePlaceholder,
            text: $viewModel.message,
            axis: .vertical
        )
        .lineLimit(5...10)
        .focused($focusedField, equals: .message)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceWhite)
        .cornerRadius(14)
    }

    var submitButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.submit() }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView().tint(.white)
                } else if viewModel.state == .success {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                } else {
                    Text(L10n.Profile.Feedback.submit)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isValid ? Color.accent : Color.accent.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!viewModel.isValid || viewModel.isSubmitting || viewModel.state == .success)
    }
}

#Preview {
    FeedbackView()
}
```

Notes:
- Uses design tokens (`Color.backgroundPrimary`, `.surfaceWhite`, `.textSecondary`, `.accent`) and `ScaleButtonStyle`, matching `LanguagePickerView`.
- `.onChange(of:initial:)` two-parameter closure is the current SwiftUI API (iOS 17+); the project already uses it elsewhere.

- [ ] **Step 2: Verify it compiles**

Run the build command from the plan header.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Features/Feedback/Views/FeedbackView.swift
git commit -m "feat(feedback): add FeedbackView form sheet"
```

---

### Task 5: Wire the Profile row to present the sheet

**Files:**
- Modify: `Neura/Features/Profile/Views/ProfileView.swift` (state flags ~line 7-12, row ~line 54, sheet modifiers ~line 137)

- [ ] **Step 1: Add the sheet state flag**

In `Neura/Features/Profile/Views/ProfileView.swift`, add a new `@State` property alongside the existing ones. Change:

```swift
    @State private var showBiometricUnavailableAlert = false
```

to:

```swift
    @State private var showBiometricUnavailableAlert = false
    @State private var showFeedback = false
```

- [ ] **Step 2: Give the Feedback row an action**

Change the line:

```swift
                            SettingsRow(icon: "fav", title: L10n.Profile.feedback)
```

to:

```swift
                            SettingsRow(icon: "fav", title: L10n.Profile.feedback) {
                                showFeedback = true
                            }
```

- [ ] **Step 3: Add the sheet modifier**

Immediately after the `.fullScreenCover(isPresented: $showPaywall) { ... }` block (the closing brace before `.alert(L10n.Profile.logOut, ...)`), add:

```swift
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
```

- [ ] **Step 4: Verify it compiles**

Run the build command from the plan header.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Neura/Features/Profile/Views/ProfileView.swift
git commit -m "feat(feedback): present FeedbackView from Profile feedback row"
```

---

### Task 6: Add Firestore security rule for `feedback`

**Files:**
- Modify: `firestore.rules`
- Modify: `firebase/firestore.rules`

- [ ] **Step 1: Add the rule block to `firestore.rules`**

In `firestore.rules`, inside `match /databases/{database}/documents { ... }`, after the `match /users/{uid}/{document=**} { ... }` block, add:

```
    // Append-only public feedback. Clients may create with a valid email +
    // non-empty message; never read, update, or delete.
    match /feedback/{id} {
      allow create: if request.auth != null
                    && request.resource.data.email is string
                    && request.resource.data.message is string
                    && request.resource.data.message.size() > 0;
      allow read, update, delete: if false;
    }
```

- [ ] **Step 2: Mirror the rule in `firebase/firestore.rules`**

Open `firebase/firestore.rules`. Add the **same** `match /feedback/{id} { ... }` block from Step 1 in the equivalent position (after the per-user match block, inside the documents match). If the file's content differs structurally, place the block alongside the other top-level collection matches.

- [ ] **Step 3: Verify the rules are syntactically consistent**

Run:

```bash
grep -n "match /feedback" firestore.rules firebase/firestore.rules
```

Expected: one match line printed from each file.

(If the Firebase CLI is installed, `firebase deploy --only firestore:rules` deploys them — deployment is a separate manual step, not part of this commit.)

- [ ] **Step 4: Commit**

```bash
git add firestore.rules firebase/firestore.rules
git commit -m "feat(feedback): allow append-only writes to feedback collection"
```

---

### Task 7: Final build + manual verification

**Files:** none (verification only)

- [ ] **Step 1: Clean build**

Run the build command from the plan header.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Manual runtime check**

Run the app on a simulator/device and confirm:
1. Profile tab → tap **Feedback** → the sheet presents with title "Send Feedback".
2. Submit button is disabled until a valid email AND a ≥3-char message are entered.
3. Entering an invalid email (e.g. `abc`) keeps the button disabled.
4. Tapping **Send** with valid input shows a spinner, then a checkmark, then auto-dismisses (~0.8s); a success haptic fires.
5. In the Firebase console, a new document appears in the `feedback` collection with `email`, `message`, `createdAt`, `appVersion`, `platform`, `locale` (and `uid` if signed in).
6. Close button (top-left) dismisses the sheet without submitting.
7. Switch app language to Arabic/Romanian and confirm the form strings are localized and (Arabic) lay out right-to-left.

- [ ] **Step 3: Final commit (if any verification fixes were needed)**

```bash
git add -A
git commit -m "fix(feedback): address verification findings"
```

(Skip if nothing changed.)

---

## Self-Review Notes

- **Spec coverage:** form fields (Task 4) ✓; validation + state flow (Task 3/4) ✓; data model incl. optional uid (Task 2) ✓; entry point sheet (Task 5) ✓; localization en/ar/ro (Task 1) ✓; security rules both files (Task 6) ✓; testing approach via build + manual (Task 7) ✓.
- **Type consistency:** `FeedbackViewModel.State` cases (`idle/submitting/success/error`), `submit()`, `isValid`, `isSubmitting` referenced identically in Tasks 3 and 4. `FeedbackService.submit(email:message:uid:)` signature matches its call site. `L10n.Profile.Feedback.*` keys defined in Task 1 match every usage.
- **Placeholders:** none — every code step contains complete code.
