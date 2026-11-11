# Family Spaces — Design Spec

**Date:** 2026-07-12
**Branch:** feature/v1.2/re-apply-calendar

---

## Goal

Let a parent create multiple **Spaces** under their single Neura account — one for themselves, one per child — each with its own Health Profile, Documents, and Calendar entries. No separate logins: only the parent ever authenticates. Free accounts get 2 Spaces (the default "Me" space + 1 child); Neura Pro unlocks unlimited Spaces, gated the same way `SubscriptionManager.canShareViaQR` gates QR sharing today.

## Context

Neura currently has **no profile/family concept anywhere** (confirmed by codebase search — zero hits for `familyMember|childProfile|subProfile|profileID|ownerID|memberID`). Every account has exactly one flat `HealthProfile`, one flat list of `Document`s, and one flat list of `CalendarEntry`s, all keyed only by Firebase `uid`. There is a real, already-shipped cloud sync layer (`Core/Services/Sync/`: `DocumentSyncService`, `CalendarEntrySyncService`, `HealthProfileSyncService`, `CustomFolderSyncService`, `PreferencesSyncService`) that end-to-end encrypts data client-side (`EncryptionService` + `KeychainManager`) and stores it in Firestore/Storage under `users/{uid}/...`. **There are real users with data already synced this way** — schema changes must not require moving or re-keying existing Storage files or Firestore documents.

Critically, every synced record (`Document`, `HealthProfile`) is stored as a single encrypted blob per Firestore document — there are no cleartext, queryable fields today (confirmed in `DocumentSyncService.swift`: only `encryptedMetadata`, `metadataIV`, `fileIV`, `storagePath` are cleartext; the full list is always fetched and decrypted client-side, never server-queried by field). This means Spaces can be introduced purely as a field inside the existing encrypted payloads, with **no Firestore/Storage path restructuring** — the lowest-risk option given live user data.

## Architecture

### Data model

- New `Space` model: `id: UUID`, `name: String`, `colorHex: String` (swatch color for the avatar chip — no emoji/photo), `createdAt: Date`, `isDefault: Bool`, `isArchived: Bool`.
- `Document` and `CalendarEntry` each gain `spaceID: UUID`. Since both are encrypted as a whole Codable blob per record, this is a pure model change — no Firestore schema change. On decode, a missing `spaceID` (pre-existing records) defaults to the primary Space's `id`; the field gets persisted the next time that record round-trips through a save, so migration is incremental and never blocks reads.
- `HealthProfile` changes from a single flat blob to a dictionary keyed by Space (`[SpaceID: HealthProfile]`), stored as one encrypted blob (mirrors today's single-doc pattern — no Firestore path change). This is the one real migration step: on first load after the update, if the old single-profile storage key exists and the new dictionary key doesn't, wrap the existing profile under the default Space's `id` and save under the new key. Idempotent — safe to run on every launch, a no-op once migrated.

### Storage & sync — no path changes

The six existing sync services keep writing to `users/{uid}/...` exactly as today. Only the Codable payload shape changes. Files on disk under `~/Documents/NeuraScans/` and in Firebase Storage don't move. This avoids any read-modify-write migration pass over existing users' encrypted documents/files — the single highest-risk item this design deliberately routes around.

**The `Space` list itself must also sync** (a gap missed in the first pass of this spec). Without it, a child space's Documents/CalendarEntries download fine on a second device or reinstall — their Firestore paths never changed — but there is no local `Space` to house them, so they're effectively invisible. A new `SpaceSyncService` mirrors the existing `CustomFolderSyncService` pattern exactly: single encrypted blob at `users/{uid}/spaces/data`, restored via the same "local wins on id conflict" merge used for custom folders, and restored **first** in `performInitialRestore` (before documents/calendar/health profile) for the same reason custom folders restore before documents — so the containers documents/entries reference already exist when everything else rebuilds.

**The default Space uses a fixed, well-known UUID** (not a randomly generated one) across every account and every device. This is what makes the cloud/local merge above correct: if the default space got a fresh random id on every local reset (e.g. logout/login), a re-login would produce two "default" spaces (local-fresh vs. cloud-original) and the `HealthProfile` dictionary — keyed by the *original* default space's id — would fail to resolve against the new one, silently resurfacing the `.sample` demo profile instead of the user's real data.

### Active Space state & switching

`ActiveSpaceManager` (`@MainActor` `ObservableObject`, injected as an environment object): holds `currentSpaceID: UUID` and the list of non-archived `Space`s, persisted in `UserDefaults`. ViewModels that already hold the full local/synced list (`DocumentsListViewModel`, calendar/agenda view models, `HealthProfileViewModel`) add an in-memory filter by `currentSpaceID` when building what they display. Switching the active Space is an in-memory filter change — instant, no network round-trip.

### UI

- **Profile tab**: new "Spaces" section with a horizontal row of avatar chips (default "Me" + each child). Tapping a chip sets it active app-wide — Home, Calendar, and Docs tabs immediately reflect the new `currentSpaceID`. A trailing "+" chip opens an "Add Space" sheet (name + color/emoji picker).
- **Gating**: if the free-tier limit (2 total Spaces) is reached, "+" opens `PaywallView` instead of the add-space sheet, following the existing `canShareViaQR`-style gate pattern in `SubscriptionManager`.
- **Delete/archive**: a "Remove" action on a Space's row sets `isArchived = true` (soft delete, confirmed choice — health records are not something to lose to an accidental tap). Archived Spaces disappear from the switcher and don't count toward the plan limit; their Documents/CalendarEntries/HealthProfile entry are left untouched in storage. A restore UI for archived Spaces is out of scope for v1 (data is recoverable via direct support in the interim).

## Testing

- `ActiveSpaceManager` filtering: switching `currentSpaceID` returns only that Space's Documents/CalendarEntries/HealthProfile.
- `HealthProfile` migration: covers (a) old key present / new key absent → wraps under default Space, (b) new key already present → no-op, (c) neither present → fresh default Space + empty profile.
- `Document`/`CalendarEntry` decode: missing `spaceID` defaults to the primary Space's `id`.
- `SubscriptionManager.canCreateSpace`: boundary at 1 vs. 2 total Spaces for free tier; always `true` for Pro.
- Default Space cannot be archived or deleted.
- Cloud restore merge: a fresh install/second device restores the same default Space id as the original device (fixed UUID, no duplicate "default" after merge), then a child Space, then that child's Documents/CalendarEntries become visible after switching to it.

## Out of scope (v1)

- Children signing in on their own device/account (explicitly rejected — parent-only access).
- Relationship type / date of birth per Space (name + avatar only, per decision).
- Restore UI for archived Spaces.
- Per-Space fine-grained permissions (not needed — single authenticated user).
