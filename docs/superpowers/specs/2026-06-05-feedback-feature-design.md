# Feedback Feature — Design

**Date:** 2026-06-05
**Status:** Approved

## Goal

Let users send their opinion about the app. The form has a required, validated
email field and a required message field. Submissions are written to a
top-level `feedback` collection in Firestore. Email is entered manually
(anonymous — not pulled from the signed-in account).

## Architecture

Follows the project's MVVM + service-layer conventions. The Firestore write
lives in a service `actor` (mirroring `PreferencesSyncService`), keeping the
network call out of the ViewModel.

New module `Features/Feedback/`:

- `ViewModel/FeedbackViewModel.swift` — `@MainActor` `ObservableObject`.
  - `@Published var email: String`
  - `@Published var message: String`
  - `@Published private(set) var state: State` where
    `enum State { case idle, submitting, success, error(String) }`
  - `var isValid: Bool` — true when email + message both pass validation.
  - `func submit() async` — sets `submitting`, calls `FeedbackService`, then
    `success` or `error`.
- `Views/FeedbackView.swift` — the form sheet UI.

New service:

- `Core/Services/FeedbackService.swift` — `actor FeedbackService` with
  `static let shared` and a single method:
  `func submit(email: String, message: String, uid: String?) async throws`.
  Performs a plain (unencrypted) `addDocument` to the `feedback` collection.

## Data Model

Written to `feedback/{autoId}`:

| Field        | Type             | Source                                          |
|--------------|------------------|-------------------------------------------------|
| `email`      | String           | User-entered (trimmed)                          |
| `message`    | String           | User-entered (trimmed)                          |
| `createdAt`  | serverTimestamp  | `FieldValue.serverTimestamp()`                  |
| `appVersion` | String           | `CFBundleShortVersionString` + build number     |
| `platform`   | String           | `"iOS <UIDevice systemVersion>"`                |
| `locale`     | String           | Current app language (`LanguageManager`)        |
| `uid`        | String? (omitted if nil) | `AuthService.shared.currentUser?.uid`   |

No client-readable document model is required; the service builds the
dictionary inline.

## Entry Point

The `Feedback` row already exists in `ProfileView` (currently has an empty
action). Wire it to present `FeedbackView` via `.sheet(isPresented:)`,
matching the app's existing modal convention. Add a `@State` flag in
`ProfileView` to drive the sheet.

## Validation & State Flow

- **Email:** trimmed, non-empty, matches a standard email format check (regex
  or `NSDataDetector`). Submit button disabled until valid.
- **Message:** trimmed, non-empty, minimum ~3 characters.
- **Flow:** `idle` → (tap submit) → `submitting` (spinner, button disabled) →
  - `success`: trigger success haptic via `HapticManager`, show brief
    confirmation, auto-dismiss the sheet.
  - `error(message)`: show inline error text + a retry button; return to a
    submittable state.

## Localization

Add keys to `Core/L10n/L10n.swift` and all three locale files
(`en.lproj`, `ar.lproj`, `ro.lproj`):

- Form title
- Email field placeholder / label
- Message field placeholder / label
- Submit button label
- Invalid-email validation message
- Success confirmation message
- Generic error message

## Firestore Security Rules

Add a write-only rule for the new collection to `firestore.rules` (and the
mirrored `firebase/firestore.rules`):

```
match /feedback/{id} {
  allow create: if request.auth != null
                && request.resource.data.email is string
                && request.resource.data.message is string
                && request.resource.data.message.size() > 0;
  allow read, update, delete: if false;
}
```

`request.auth != null` is light anti-spam — the app signs users in during
onboarding regardless. Email remains manually entered. Read/update/delete are
denied so the collection is append-only from the client.

## Testing

No test target exists in the project. Verification is a clean
`xcodebuild ... build` plus a manual run: open Profile → Feedback, confirm
validation gating, submit, and verify a document lands in the `feedback`
collection.

## Out of Scope (YAGNI)

- Star rating and category picker (explicitly dropped).
- Reading feedback back into the app.
- Per-user feedback history.
- Encryption (feedback is not sensitive personal health data).
