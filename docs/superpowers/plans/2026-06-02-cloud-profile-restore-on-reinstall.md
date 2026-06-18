# Cloud Profile Restore on Reinstall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure a user's profile, medical areas, and location are uploaded to Firebase at onboarding completion and restored on reinstall, so signing in with the same account skips data entry.

**Architecture:** Add a `SyncQueueManager.enqueueProfileUpload` call at onboarding completion (the core fix), plus a small self-contained preferences sync unit (`UserPreferences` + `PreferencesSyncService`) mirroring the existing `HealthProfileSyncService`, wired into `saveProfile()` and `performInitialRestore()`.

**Tech Stack:** SwiftUI, Firebase Firestore, CryptoKit (AES-GCM via `EncryptionService`). iOS app, no test target — verification is `xcodebuild` (simulator) + manual flow.

**Verification note:** No unit-test target exists. "Verify" = build for the simulator and/or describe the manual flow. Build command throughout:
```bash
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```
(Filter output with `| grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`.)

**Reference — existing patterns to mirror:**
- `Neura/Core/Services/Sync/HealthProfileSyncService.swift` — `actor`, `upload`/`download` to `users/{uid}/profile/data` with `{encryptedData, iv, updatedAt}`.
- `EncryptionService.encrypt(_ data: Data, key:) -> (iv: Data, ciphertext: Data)` and `EncryptionService.decrypt(ciphertext:iv:key:) -> Data` (signatures confirmed in HealthProfileSyncService).
- `SyncQueueManager.enqueueProfileUpload` guards on `AuthService.shared.currentUser?.uid` + `KeychainManager.shared.currentKey`.

---

## File Structure

- `Neura/Core/Services/Sync/UserPreferences.swift` — **create**. `Codable` model `{ medicalAreas: [String]; location: String }`.
- `Neura/Core/Services/Sync/PreferencesSyncService.swift` — **create**. Encrypted upload/download to `users/{uid}/preferences/data`.
- `Neura/Core/Services/Sync/SyncQueueManager.swift` — **modify**. Add `enqueuePreferencesUpload`; extend `performInitialRestore` to restore preferences.
- `Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift` — **modify**. `saveProfile()` enqueues profile + preferences uploads.

---

### Task 1: Core fix — upload the profile at onboarding completion

**Files:**
- Modify: `Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift` (`saveProfile()`, around line 263-265)

- [ ] **Step 1: Enqueue the profile upload after local save**

Find this block in `saveProfile()`:

```swift
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "health_profile_data")
        }
```

Replace it with:

```swift
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "health_profile_data")
        }
        // Upload to Firestore so a future reinstall + relogin restores it
        // (and hasExistingCloudData detects this user as returning).
        SyncQueueManager.shared.enqueueProfileUpload(profile)
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift
git commit -m "fix: upload profile to cloud at onboarding completion"
```

---

### Task 2: UserPreferences model

**Files:**
- Create: `Neura/Core/Services/Sync/UserPreferences.swift`

- [ ] **Step 1: Create the model**

```swift
import Foundation

/// Onboarding-set preferences that should survive a reinstall:
/// the user's selected medical areas and their location string.
struct UserPreferences: Codable {
    var medicalAreas: [String]
    var location: String
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/Services/Sync/UserPreferences.swift
git commit -m "feat: add UserPreferences sync model"
```

---

### Task 3: PreferencesSyncService

**Files:**
- Create: `Neura/Core/Services/Sync/PreferencesSyncService.swift`

- [ ] **Step 1: Create the service (mirrors HealthProfileSyncService)**

```swift
import Foundation
import FirebaseFirestore
import CryptoKit

// MARK: - Preferences Sync Service

/// Encrypted sync of onboarding preferences (medical areas + location) to
/// `users/{uid}/preferences/data`, mirroring HealthProfileSyncService.
actor PreferencesSyncService {
    static let shared = PreferencesSyncService()

    private init() {}

    // MARK: - Upload

    func upload(_ prefs: UserPreferences, uid: String, key: SymmetricKey) async throws {
        let data = try JSONEncoder().encode(prefs)
        let (iv, ciphertext) = try EncryptionService.encrypt(data, key: key)

        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("preferences").document("data")
            .setData([
                "encryptedData": ciphertext,
                "iv": iv,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Download

    func download(uid: String, key: SymmetricKey) async throws -> UserPreferences? {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("preferences").document("data")
            .getDocument()

        guard let data = snapshot.data(),
              let ciphertext = data["encryptedData"] as? Data,
              let iv = data["iv"] as? Data else { return nil }

        let decrypted = try EncryptionService.decrypt(ciphertext: ciphertext, iv: iv, key: key)
        return try JSONDecoder().decode(UserPreferences.self, from: decrypted)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: `** BUILD SUCCEEDED **`. If `EncryptionService.encrypt`/`decrypt` signatures differ, match them to the usage in `HealthProfileSyncService.swift` exactly.

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/Services/Sync/PreferencesSyncService.swift
git commit -m "feat: add PreferencesSyncService"
```

---

### Task 4: SyncQueueManager — enqueue upload + restore preferences

**Files:**
- Modify: `Neura/Core/Services/Sync/SyncQueueManager.swift`

- [ ] **Step 1: Add `enqueuePreferencesUpload` after `enqueueProfileUpload`**

Find:

```swift
    func enqueueProfileUpload(_ profile: HealthProfile) {
        guard let uid = AuthService.shared.currentUser?.uid,
              let key = KeychainManager.shared.currentKey else { return }

        Task {
            try? await HealthProfileSyncService.shared.upload(profile: profile, uid: uid, key: key)
        }
    }
```

Insert immediately after it:

```swift
    // MARK: - Preferences Upload

    func enqueuePreferencesUpload(_ prefs: UserPreferences) {
        guard let uid = AuthService.shared.currentUser?.uid,
              let key = KeychainManager.shared.currentKey else { return }

        Task {
            try? await PreferencesSyncService.shared.upload(prefs, uid: uid, key: key)
        }
    }
```

- [ ] **Step 2: Restore preferences inside `performInitialRestore`**

Find the profile-restore block inside `performInitialRestore`:

```swift
            // 1. Health profile
            if let profile = try? await HealthProfileSyncService.shared.download(uid: uid, key: key),
               let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: "health_profile_data")
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
            }
```

Insert immediately after that `if` block (before the `// 2. Documents` comment):

```swift
            // 1b. Preferences (medical areas + location)
            if let prefs = try? await PreferencesSyncService.shared.download(uid: uid, key: key) {
                UserDefaults.standard.set(prefs.location, forKey: "user_location")
                if let areasData = try? JSONEncoder().encode(prefs.medicalAreas) {
                    UserDefaults.standard.set(areasData, forKey: "onboarding_medical_areas")
                }
                NotificationCenter.default.post(name: .healthProfileRestored, object: nil)
            }
```

(Reusing `.healthProfileRestored` triggers Home's profile reload, which re-reads
`user_location` from `UserDefaults` on the next render.)

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/Sync/SyncQueueManager.swift
git commit -m "feat: sync and restore onboarding preferences"
```

---

### Task 5: Upload preferences at onboarding completion

**Files:**
- Modify: `Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift` (`saveProfile()`, end of method, around lines 267-285)

- [ ] **Step 1: Build UserPreferences and enqueue, reusing the location string already computed**

Find the end of `saveProfile()`:

```swift
        // Persist location
        let location: String
        switch (state.city.trimmingCharacters(in: .whitespaces).isEmpty,
                state.country.trimmingCharacters(in: .whitespaces).isEmpty) {
        case (false, false): location = "\(state.city), \(state.country)"
        case (false, true):  location = state.city
        case (true, false):  location = state.country
        case (true, true):   location = ""
        }
        UserDefaults.standard.set(location, forKey: "user_location")
    }
```

Replace it with:

```swift
        // Persist location
        let location: String
        switch (state.city.trimmingCharacters(in: .whitespaces).isEmpty,
                state.country.trimmingCharacters(in: .whitespaces).isEmpty) {
        case (false, false): location = "\(state.city), \(state.country)"
        case (false, true):  location = state.city
        case (true, false):  location = state.country
        case (true, true):   location = ""
        }
        UserDefaults.standard.set(location, forKey: "user_location")

        // Upload preferences to Firestore so they restore on reinstall.
        let prefs = UserPreferences(medicalAreas: areas, location: location)
        SyncQueueManager.shared.enqueuePreferencesUpload(prefs)
    }
```

(`areas` is the `state.medicalAreas.map(\.rawValue)` array already computed earlier in
`saveProfile()` for the `onboarding_medical_areas` write — reuse it, do not recompute.)

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Features/Onboarding/ViewModel/OnboardingViewModel.swift
git commit -m "feat: upload medical areas + location at onboarding completion"
```

---

### Task 6: Manual end-to-end verification

- [ ] **Step 1: Fresh onboarding uploads data**

Run the app on a signed-out simulator/device. Complete onboarding with a name, location,
and a medical area. After finishing, in the Firebase console confirm both
`users/{uid}/profile/data` and `users/{uid}/preferences/data` documents exist.

- [ ] **Step 2: Reinstall restores data**

Delete the app, reinstall, launch, and on the Welcome step sign in with the SAME
account. Expected: onboarding skips all data-entry steps and lands on the dashboard;
the Home SecureProfileCard shows the restored name and location.

---

## Self-Review

- **Spec coverage:**
  - Part A core fix (profile upload at onboarding) → Task 1. ✓
  - `UserPreferences` model → Task 2. ✓
  - `PreferencesSyncService` (encrypted, `users/{uid}/preferences/data`) → Task 3. ✓
  - `enqueuePreferencesUpload` + restore in `performInitialRestore` (writes `user_location` String, `onboarding_medical_areas` JSON `[String]`) → Task 4. ✓
  - Build `UserPreferences` from state + enqueue at `saveProfile()` → Task 5. ✓
  - Verification (console + reinstall flow) → Task 6. ✓
- **Placeholders:** none — all code/commands concrete.
- **Type consistency:** `UserPreferences(medicalAreas:location:)` defined in Task 2 is constructed in Task 5 and (de)serialized in Task 3. `PreferencesSyncService.shared.upload(_:uid:key:)` / `download(uid:key:)` defined in Task 3 are called in Task 4. `enqueuePreferencesUpload(_:)` defined in Task 4 is called in Task 5. `areas` reused from existing code in Task 5 (not redefined).
- **Risk:** `EncryptionService` signature drift — Task 3 explicitly says match `HealthProfileSyncService` usage. Restore ordering — preferences write occurs before its notification post, so Home reads fresh values on re-render.
