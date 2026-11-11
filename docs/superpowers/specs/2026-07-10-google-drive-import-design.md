# Google Drive Import — Design

## Problem

Users want to import documents into Neura directly "from Google Drive." Today, `AddDocumentSheet` offers three sources — Scan, Photos, Files — and the Files option already opens the system document picker (`UIDocumentPickerViewController` via SwiftUI's `.fileImporter`), which surfaces Google Drive as a browsable location automatically *if* the user has the official Google Drive app installed and signed in (Apple's document-provider extension mechanism). There is currently no Drive-specific entry point or affordance in the UI.

## Decision: no OAuth, no custom Drive browser

Neura already ships the GoogleSignIn SDK, but only for Sign in with Google auth (default OIDC scopes — no `drive.readonly`). Building a full in-app Drive browser would require a Google Cloud OAuth consent screen, Drive-scoped auth, GTLRDrive REST integration, a custom file browser UI, and handling Google Docs/Sheets export — a large surface for a feature that iOS already substantially provides for free via the system file picker.

**We are explicitly building the lightweight version**: reuse the existing file-import pipeline, add a clearly-labeled entry point, and guide the user to Drive inside the system picker. We are not building OAuth-based in-app Drive browsing.

## Flow

1. User taps the FAB → `AddDocumentSheet` shows 4 rows: Scan / Photos / Files / **Import from Google Drive**.
2. Tapping "Import from Google Drive" dismisses the sheet and calls a new `DocumentsListViewModel.startGoogleDriveImport()`, gated by the same `ensureCanUpload()` paywall chokepoint every other source uses.
3. **First time only** (tracked via a `UserDefaults` bool `hasSeenDriveImportTip`): a single `.alert` shows before the picker opens —
   - Title: "Importing from Google Drive"
   - Body: "In the browser that opens, tap Browse, then Locations, then Google Drive. If you don't see it, install the Google Drive app and sign in first."
   - One button: "Continue" → dismisses alert, opens picker.
   - Subsequent taps skip straight to the picker.
4. The system file picker opens — the **same** `.fileImporter(isPresented:, allowedContentTypes: [.pdf, .image])` already used by "Files." There is no public iOS API to pre-navigate the picker to a specific document-provider location, so both buttons open the identical system UI; the tip is the only way we point users toward Drive inside it.
5. If the Google Drive app is installed and signed in, it appears under Locations. The user picks a file; iOS downloads it locally via Drive's file-provider extension (native mechanism, not our code — may take a moment on a large file over a slow connection).
6. The picker returns a local URL through the existing `handleFileImport(_:)` completion handler — no new handler needed. This sets `pendingPreview = .importedFile(url)`, opens `DocumentMetadataView` for category/doctor/notes/expiry, and `saveDocument` copies the file in via `DocumentFileManager`, identical to a Files- or Scan-sourced document.
7. Native Google Docs/Sheets/Slides files are typically auto-exported to PDF by Drive's file-provider extension when opened this way. If a given file can't be exported to a supported type, it's simply not selectable in the picker (grayed out) — same behavior as any other incompatible file today. No special-case handling required.
8. Errors (user cancels, download fails) reuse the existing `handleFileImport` failure branch — no new error UI.

## Components touched

- **`Neura/Features/Documents/Views/Components/AddDocumentSheet.swift`** — add a 4th `optionRow` for Google Drive, using `Image("google-drive").renderingMode(.original)` (full-color brand mark) instead of the template-tinted style used by the other three icons.
- **`Neura/Resources/Assets.xcassets/google-drive.imageset/`** — new full-color image asset for the Drive logo (same pattern as the existing `calendar-events`/`calendar-medicine` imagesets).
- **`Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`** — add `startGoogleDriveImport()`, mirroring `startFileImport()`: same `ensureCanUpload()` gate, same `showFileImporter = true`, plus the one-time tip alert state/logic gated on `hasSeenDriveImportTip` in `UserDefaults`.
- **`Neura/Features/Documents/Views/DocsView.swift`** — wire the new `onGoogleDrive` closure from `AddDocumentSheet` to `viewModel.startGoogleDriveImport()`, and add the one-time tip `.alert`.

## Explicitly out of scope

- No changes to `Document.swift` (no `source`/provenance field) — Drive-imported files are stored and treated identically to any other imported file, per product decision.
- No OAuth, no Drive REST API calls, no custom in-app Drive file browser.
- No detection of whether the Google Drive app is installed (no reliable public API for this without a URL scheme entry we don't otherwise need) — the tip text handles the "not installed" case with instructions rather than app-side detection.

## Testing

No test target exists in this project. Verification is manual:
- Simulator: confirm the 4th row renders with the Drive icon at correct size/color, confirm the tip alert shows once then never again (via `UserDefaults` flag), confirm paywall gating still triggers correctly when the free upload limit is reached.
- Physical device with the Google Drive app installed and signed in: confirm Drive appears under Locations in the picker, confirm a picked file flows through metadata entry and appears in the documents list identically to a Files-imported document.
