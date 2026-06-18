# Design: Cloud Profile Restore on Reinstall

Date: 2026-06-02
Branch: feature/new-onboarding

## Problem

When a fresh user completes onboarding and enters their data, then later reinstalls
the app and signs in with the same Apple/Google account, onboarding asks them to
re-enter all their data instead of restoring it from the cloud.

## Root cause

`OnboardingViewModel.saveProfile()` persists the new user's profile **only** to
`UserDefaults` (`health_profile_data`) — it never uploads to Firestore. The only code
path that uploads the profile is `HealthProfileViewModel.save()`, which fires when the
user later *edits* the profile. So a user who completes onboarding but never edits has
their data on-device only.

The returning-user gate works like this (already implemented):
- After sign-in at the Welcome step, `OnboardingViewModel.checkReturningUser()` calls
  `AuthService.hasExistingCloudData(uid:)`, which checks whether
  `users/{uid}/profile/data` exists in Firestore.
- If it exists → `isReturningUser = true` → `finalize()` skips remaining data-entry
  steps, and `SyncQueueManager.performInitialRestore()` (triggered from
  `AuthService.onSignInSuccess`) downloads + decrypts the profile and documents.

Because nothing was ever uploaded, `hasExistingCloudData` returns `false` and the user
is treated as new.

Sign-in happens at the Welcome step, which is **before** the data-entry steps, so at
`finalize()` time the user is already authenticated: the uid and the per-user encryption
key (`KeychainManager.shared.currentKey`, set during `onSignInSuccess`) are both
available.

## Scope

Restore on reinstall covers: health profile, selected medical areas, and location.

Note: `onboarding_medical_areas` currently has **no reader** in the app (written at
onboarding, cleared on account delete, never displayed). It is included here for
completeness and future use; restoring it has no visible effect today. `user_location`
**is** read in `HomeView` (SecureProfileCard) and is user-visible.

Out of scope: edit-time syncing of medical areas / location (both are written only at
onboarding and never edited afterward), and document sync (already handled).

## Architecture

### Part A — Upload profile at onboarding completion (the core fix)

In `OnboardingViewModel.saveProfile()`, after encoding the profile into
`UserDefaults["health_profile_data"]`, also call:

```swift
SyncQueueManager.shared.enqueueProfileUpload(profile)
```

This reuses the existing upload path (`HealthProfileSyncService.upload`) that profile
edits already use. It encrypts the profile and writes `users/{uid}/profile/data`. After
this, `hasExistingCloudData` returns `true` on the next reinstall, enabling the
already-built returning-user / restore flow.

`saveProfile()` already begins with `guard !isReturningUser else { return }`, so the
upload only runs for genuinely new users. `enqueueProfileUpload` itself no-ops if
uid/key are missing.

### Part B — Medical areas + location sync

A self-contained sync unit mirroring `HealthProfileSyncService`:

- **`UserPreferences`** (`Neura/Core/Services/Sync/UserPreferences.swift`) — a `Codable`
  struct:
  ```swift
  struct UserPreferences: Codable {
      var medicalAreas: [String]
      var location: String
  }
  ```

- **`PreferencesSyncService`** (`Neura/Core/Services/Sync/PreferencesSyncService.swift`)
  — singleton with:
  - `upload(_ prefs: UserPreferences, uid: String, key: SymmetricKey) async throws`
  - `download(uid: String, key: SymmetricKey) async throws -> UserPreferences?`
  - Stored encrypted at `users/{uid}/preferences/data` using the same
    `{encryptedData, iv, updatedAt}` shape and `EncryptionService` as
    `HealthProfileSyncService`. Existing Firestore rules (`users/{uid}/{document=**}`)
    already authorize this path — no rules change.

- **`SyncQueueManager.enqueuePreferencesUpload(_ prefs: UserPreferences)`** — same guard
  + fire-and-forget `Task` pattern as `enqueueProfileUpload`.

- **`OnboardingViewModel.saveProfile()`** — after persisting `onboarding_medical_areas`
  and `user_location` locally, build a `UserPreferences` from `state` (medical-area
  rawValues + the same computed location string) and call
  `SyncQueueManager.shared.enqueuePreferencesUpload(prefs)`.

- **`SyncQueueManager.performInitialRestore(uid:key:)`** — add a step that downloads
  preferences and writes them back to `UserDefaults` in the readers' expected formats:
  - `user_location` ← `prefs.location` (`String`)
  - `onboarding_medical_areas` ← `JSONEncoder().encode(prefs.medicalAreas)` (`[String]`)

  This write happens before/with the existing `.healthProfileRestored` post so that the
  Home re-render (driven by the profile reload) reads the restored location.

## Data flow (reinstall)

1. User reinstalls, lands on Welcome, taps Apple/Google sign-in.
2. `AuthService.onSignInSuccess` → `performInitialRestore(uid:key:)` starts.
3. `checkReturningUser()` → `hasExistingCloudData` now finds `users/{uid}/profile/data`
   → `isReturningUser = true`.
4. `finalize()` runs immediately; `saveProfile()` early-returns (returning user), so no
   overwrite.
5. `performInitialRestore` downloads + decrypts profile (→ `health_profile_data`) and
   preferences (→ `user_location`, `onboarding_medical_areas`), posts
   `.healthProfileRestored`.
6. App shows Dashboard/Home with restored data; no data-entry prompts.

## Error handling

- Profile and preferences uploads are independent best-effort `Task`s. If one fails
  (e.g. offline), the other still proceeds. The returning-user gate depends only on the
  profile doc, so a failed *preferences* upload never blocks the core flow.
- `download` returns `nil` on a missing/undecryptable doc; restore simply skips that
  piece, leaving existing local values intact.

## Files

- Modify: `Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift`
  (`saveProfile()` — two enqueue calls).
- Modify: `Neura/Core/Services/Sync/SyncQueueManager.swift`
  (`enqueuePreferencesUpload`, extend `performInitialRestore`).
- Create: `Neura/Core/Services/Sync/UserPreferences.swift`.
- Create: `Neura/Core/Services/Sync/PreferencesSyncService.swift`.

## Testing / verification

No unit-test target exists. Verify by `xcodebuild` (simulator) + manual flow:
1. Fresh onboarding with data → background → confirm `users/{uid}/profile/data` and
   `users/{uid}/preferences/data` exist (Firebase console).
2. Delete app, reinstall, sign in with the same account → onboarding is skipped and the
   profile + location appear restored on Home.
