# Account Avatars & Switch Polish — Design Spec

**Date:** 2026-07-13
**Branch:** feature/v1.2/re-apply-calendar
**Builds on:** `2026-07-12-family-spaces-design.md` (implemented — `Space`/`ActiveSpaceManager`, user-facing copy "Accounts")

---

## Goal

The shipped Accounts switcher (Profile tab) uses plain color-filled circles with an initial letter. This adds: (1) a real profile photo per account, with crop/reposition, (2) a way to edit an existing account's name/photo — including the auto-created default account, which never got a naming prompt, and (3) a brief switch-loader plus general visual polish on the chip row.

## Context

Reused patterns confirmed in the codebase:
- `CardBackgroundPickerSheet.swift` already does `PhotosPicker`/`PhotosPickerItem` → `UIImage` → save-to-disk, the exact shape needed here.
- `CardBackground`'s storage pattern (JPEG file in a dedicated directory, only a filename reference kept in the synced/Codable model) is the template for avatar storage — **not** `DocumentFileManager`, which is tightly coupled to medical-document metadata/free-tier counting.
- No cropping UI exists anywhere in the codebase — this is a new, from-scratch SwiftUI view (no third-party packages, per this project's pure-Apple-frameworks convention).

## Architecture

### Avatar storage

New `AccountAvatarStore` (mirrors `CardBackground`'s file-storage half, scoped to avatars):
- Directory: `Documents/AccountAvatars/`, filename `<spaceID>.jpg`.
- `save(_ image: UIImage, for spaceID: UUID) -> String?` — JPEG-encodes and writes, returns the filename.
- `resolveURL(for filename: String) -> URL`, `loadImage(filename: String) -> UIImage?`, `delete(filename: String)`.

`Space` gains `var avatarFilename: String?`. Since `Space` already round-trips through `ActiveSpaceManager`'s local UserDefaults blob and `SpaceSyncService`'s Firestore blob unchanged in shape (adding an `Optional` field decodes safely against old data, same pattern as `Document.spaceID`), only the filename reference travels through sync — **the image bytes stay local to the device that set them** (explicit scope decision: no Storage upload/download for avatars). A second device shows the color+initial fallback until a photo is set there too.

### Crop flow

New `AvatarCropView` (full-screen cover): takes a source `UIImage`, shows it behind a circular mask with `DragGesture` (reposition) and `MagnificationGesture` (zoom, clamped to a sane min/max), "Cancel" / "Use Photo" toolbar actions. On confirm, renders the current transform to a fixed 400×400 `UIImage` (via `ImageRenderer` or manual `UIGraphicsImageRenderer` compositing) and hands it back via a completion closure — no dependency on any other new screen.

### Create / edit account sheet

`AddSpaceSheet` becomes a shared create/edit sheet:
- A circular photo well at the top (shows the current avatar, or a placeholder camera icon) — tapping it opens `PhotosPicker`, then `AvatarCropView` on selection.
- Name field (unchanged).
- Drop the manual color-swatch picker — color is now only the *fallback* when no photo is set, derived deterministically from the account id (same technique already used for `CustomFolder.colorSeed`), not user-chosen.
- New `mode: .create` / `.edit(Space)` parameter. Edit mode pre-fills name + photo and is reachable via a new **"Edit"** context-menu action, available on every account including the default one (which today has no naming/photo entry point at all).

### Switch loader & chip polish

- Tapping a non-active chip: show a brief (~0.5s) full-screen dimmed overlay with a `ProgressView` spinner, then call `activeSpaceManager.setActive(id)` and dismiss the overlay. Purely perceived feedback — the actual switch is already instant (in-memory filter), no real async work backs this delay.
- Chip visuals: avatar diameter increases (~60pt vs. 44pt), a drop shadow matching the existing `BiometricLockRow` style (`Color.black.opacity(0.06), radius: 6, x: 0, y: 4`), a two-layer active-state ring (white gap + accent stroke, standard iOS selected-avatar treatment), and the "+" chip gets a dashed-border treatment instead of a plain filled circle.

## Testing

- New account creation with a photo: crop, save, filename persisted on the `Space`, avatar renders in the chip row.
- New account creation with no photo: falls back to the deterministic color+initial exactly as today.
- Editing the default account's name/photo for the first time.
- Switch loader appears and the correct account's data (Docs/Calendar/Health Profile) shows after it dismisses.
- A `Space` decoded from old data (no `avatarFilename` key) renders its color+initial fallback without crashing.

## Out of scope

- Cross-device avatar sync (explicit decision — local-only for now).
- Any change to the free-tier account-count gating (unchanged: 1 additional free, Pro beyond that).
