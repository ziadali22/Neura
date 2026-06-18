# Google-Drive-Style Cloud Sync — Rebuild Design Spec

**Date:** 2026-06-05
**Branch:** feature/new-onboarding
**Firebase project:** neura-42024

---

## Goal

Logging in with Apple or Google on **any** device returns **all** of the user's data — health profile, preferences, and document files — with **no loss even after the app is deleted**. The model is Google Drive's: the encryption key is recoverable from the authenticated account (access-controlled, encrypted at rest), not bound to a single device.

## Why it's broken today

1. **Writes never reach Firebase.** Confirmed empirically: creating a document leaves Firestore/Storage empty. Almost certainly **security rules deny the writes** (or Storage was never enabled). Every upload uses `try?`, so the rejection is invisible.
2. **Key is device-bound.** The AES key lives only in iCloud Keychain. A new device, a disabled iCloud Keychain, or a different ecosystem ⇒ a valid login but an unreadable cloud ⇒ apparent total data loss.
3. **No upload durability.** `enqueueUpload`/`enqueueProfileUpload`/`enqueuePreferencesUpload` fire `Task {}` with `try?` and never retry. An offline scan or an app killed mid-upload is lost forever.
4. **Regression (mine, to be removed):** `AuthService.resolveKey` leaves the key nil for ~15s after sign-in (dropping uploads) and can mint a *new* key when iCloud is merely slow, permanently poisoning a recoverable account.

---

## Architecture

### Firebase data model

```
Firestore:
  users/{uid}/keys/master        → { key: <base64 raw 256-bit AES key>, createdAt }
  users/{uid}/profile/data       → { encryptedData, iv, updatedAt }
  users/{uid}/preferences/data   → { encryptedData, iv, updatedAt }
  users/{uid}/documents/{docId}  → { encryptedMetadata, metadataIV, fileIV, storagePath, createdAt, updatedAt }

Storage:
  users/{uid}/documents/{docId}.enc   → AES-GCM encrypted file bytes
```

### Phase 1 — Unblock writes + observability

**Security rules (deployed by user via Console copy-paste; also committed to repo for version control).**

`firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

`storage.rules`:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Observability.** New `SyncLog` (wrapping `os.Logger`, subsystem `com.neura.sync`). Every sync operation logs start / success / failure-with-error. The silent `try?` calls in `SyncQueueManager` become `do/catch` that log and update per-document `SyncStatus`.

### Phase 2 — Account-recoverable key

New actor `EncryptionKeyService` owns the canonical key at `users/{uid}/keys/master`. Firestore is the source of truth; iCloud Keychain is an offline cache.

**`resolveKey(uid:) async -> SymmetricKey?`** (online sign-in path):
1. Fetch `users/{uid}/keys/master` from Firestore.
   - **Present** → decode, overwrite local Keychain cache, return. (Returning user on any device.)
   - **Absent** → check local Keychain:
     - Keychain has a key → upload it to Firestore as canonical, return. (Migration: existing user whose key predates server storage; their cloud data stays decryptable and becomes portable.)
     - Keychain empty → create a fresh key, upload to Firestore, save to Keychain, return. (Genuinely new user.)
2. **Offline / fetch fails:** fall back to the Keychain cache if present; otherwise return `nil` and **defer** all sync (never create a new key when Firestore can't be confirmed empty — that's the poisoning trap).

`KeychainManager` gains `tryLoadKey` (no-create, already added) and a public `store(_:for:)` so the service can cache a downloaded key. `AuthService.resolveKey` (the racy version) is deleted; `restoreCloudData` calls `EncryptionKeyService.resolveKey` then `performInitialRestore`.

### Phase 3 — Durable upload queue

New `PendingSyncStore` persists un-synced operations to a JSON file in Application Support so they survive app kills.

- **Operation:** `{ kind: documentUpload | documentMetadata | documentDelete | profileUpload | preferencesUpload, id: UUID? }`. Keyed by `(kind, id)`; a `documentDelete` supersedes a pending `documentUpload`/`documentMetadata` for the same id.
- Document payloads are **not** copied into the queue — at drain time the `Document` is re-read from `DocumentFileManager` metadata + disk; profile/preferences are re-read from `UserDefaults` (latest-wins).
- `SyncQueueManager.enqueueX` records the op in `PendingSyncStore` **then** attempts immediately. Success removes it; failure leaves it for retry.
- **Drain triggers:** after key resolution on launch, on sign-in, on `scenePhase == .active`, and on network regain.

New `NetworkMonitor` (singleton wrapping `NWPathMonitor`) publishes `isConnected`; `SyncQueueManager` drains the queue when connectivity returns.

---

## Files

### Create
- `firestore.rules` — repo copy of Firestore rules (user pastes into Console)
- `storage.rules` — repo copy of Storage rules (user pastes into Console)
- `Neura/Core/Services/Sync/SyncLog.swift` — os.Logger wrapper
- `Neura/Core/Services/Sync/EncryptionKeyService.swift` — canonical server key + resolution/migration
- `Neura/Core/Services/Sync/PendingSyncStore.swift` — durable pending-operations persistence
- `Neura/Core/Services/Sync/NetworkMonitor.swift` — NWPathMonitor connectivity

### Modify
- `Neura/Core/Services/Encryption/KeychainManager.swift` — add public `store(_:for:)`; keep `tryLoadKey`
- `Neura/Core/Services/Auth/AuthService.swift` — delete racy `resolveKey`; use `EncryptionKeyService`; drain queue after key resolves
- `Neura/Core/Services/Sync/SyncQueueManager.swift` — durable queue, logging, drain logic, network observation
- `Neura/Core/Services/Sync/DocumentSyncService.swift` — add logging (logic unchanged)
- `Neura/Core/Services/Sync/HealthProfileSyncService.swift` — add logging
- `Neura/Core/Services/Sync/PreferencesSyncService.swift` — add logging

---

## Manual steps (user)

1. Firebase Console → **Storage** → ensure it is enabled (Get Started) for `neura-42024`.
2. Firebase Console → **Firestore → Rules** → paste `firestore.rules` → Publish.
3. Firebase Console → **Storage → Rules** → paste `storage.rules` → Publish.
4. Verify: create a document in the app → confirm it appears under `users/{uid}/documents` in Firestore and `users/{uid}/documents/*.enc` in Storage.

---

## Out of scope

- End-to-end (zero-knowledge) encryption — explicitly traded away for account recovery.
- Real-time multi-device live sync / conflict resolution beyond latest-wins.
- Cloud Functions changes (QR sharing remains as-is).

## Honest caveat

Data already encrypted with a key that is no longer present on the device or in Firestore is **unrecoverable**. These changes prevent future loss and make all *future* data portable; they cannot always undo past loss.
