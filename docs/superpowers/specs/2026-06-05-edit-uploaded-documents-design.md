# Edit Uploaded Documents — Design Spec

**Date:** 2026-06-05
**Branch:** feature/new-onboarding (work area; feature may move to its own branch)
**Status:** Approved for planning

## Summary

Add an **Edit** action to the document viewer's three-dot menu that opens the *same form* used during upload (`DocumentMetadataView`), pre-filled with the document's current values. Users can edit all metadata fields. Scanned documents and single images additionally get the full page editor (add / remove / re-scan pages). Imported PDFs are metadata-only. **Edit replaces the existing Rename** menu item.

## Goals

- Reuse the upload form (`DocumentMetadataView`) for editing — one source of truth, no parallel form.
- Pre-fill the form with the document's existing name, category, specialization, date, doctor, and notes.
- Allow page editing (add / remove / re-scan) for `.scan` and `.image` documents.
- Keep imported `.pdf` documents metadata-only (avoid rasterization quality loss).
- Persist changes in place (overwrite the existing file; do not create a duplicate document).
- Fix the latent staleness bug where the viewer keeps showing old values after an edit.

## Non-Goals (out of scope)

- Page **reordering** — the upload form doesn't support it either.
- Page editing for **imported PDFs** — rasterizing real PDFs degrades quality and loses selectable text.
- New automated tests — no test target exists in the project.

## Decisions (confirmed with user)

1. **Scope:** Metadata **and** pages.
2. **Menu:** Edit **replaces** Rename (Edit is a superset).
3. **Imported PDFs:** metadata-only; scans and images get the full page editor.

## Background — current code

- **Upload form:** `Neura/Features/Documents/Views/Components/ScanDocumentView.swift` defines `DocumentMetadata` (struct), `DocumentPreviewContent` (`.scannedImages([UIImage])` / `.importedFile(URL)`), and `DocumentMetadataView`. The view does `@State private var metadata = DocumentMetadata()` and sets `metadata.name = defaultName` in `onAppear`. Emits `onSave: (DocumentMetadata, DocumentPreviewContent) -> Void`.
- **Viewer:** `Neura/Features/Documents/Views/Components/DocumentViewerView.swift` holds `let document: Document`, `onDelete`, and `onRename: ((String) -> Void)?`. Three-dot `Menu` has Rename / Info / Share / Share QR / Delete. Rename uses an alert (`showRename`, `renameText`).
- **Model:** `Neura/Core/Models/Document.swift`. `documentType` is `let` (immutable). Fields: `name`, `filename`, `createdAt`, `category?`, `specialization?`, `doctorName?`, `notes?`, `tags?` (custom folder IDs as UUID strings). `isPDF == .pdf || .scan`, `isImage == .image`.
- **File manager:** `Neura/Core/Services/DocumentFileManager.swift`. Files named `{id}.{ext}`. `savePDF(from:name:documentID:)` and `saveImage(_:name:documentID:)` **throw `.duplicateDocument` if the file already exists** (so they cannot overwrite). `loadPDF`, `loadImage`, `saveMetadata`, `deleteDocument(id:)`.
- **ViewModel:** `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`. `@Published var documents: [Document]` is the source of truth. `saveDocument` creates a new file + `recordUpload()` + `enqueueUpload`. `renameDocument` mutates name → `persistMetadata()` → `enqueueMetadataUpdate`. `persistMetadata()` calls `fileManager.saveMetadata(documents)`.
- **PDF generation:** `Neura/Core/Services/PDFGenerator.swift` builds a `PDFDocument` from `[UIImage]`. **No reverse (PDF→images) renderer exists yet.**
- **L10n:** `common.edit` = "Edit" already exists (`L10n.Common.edit`). No new strings strictly required.

## Architecture

### Field mapping: `Document` ⇄ `DocumentMetadata`

The two types don't line up; the edit-seeding init and the save-back path must translate both directions:

| DocumentMetadata | Document | Seed (Document→Metadata) | Save back (Metadata→Document) |
|---|---|---|---|
| `name: String` | `name: String` | direct | direct |
| `category: DocumentCategory?` | `category: DocumentCategory?` | direct | direct |
| `customFolderId: UUID?` | `tags: [String]?` | parse first UUID-string in `tags` | write `tags = [uuid.uuidString]` (or clear) |
| `specialization: MedicalSpecialization` (non-opt) | `specialization: MedicalSpecialization?` | `?? .other` | store directly (non-nil) |
| `doctorName: String` (non-opt) | `doctorName: String?` | `?? ""` | `""` → `nil`, else trimmed value |
| `notes: String` (non-opt) | `notes: String?` | `?? ""` | `""` → `nil`, else trimmed value |
| `documentDate: Date` | `createdAt: Date` | direct | direct |

### 1. `DocumentMetadataView` — add edit mode

- Add optional init parameter `editingDocument: Document?` (default `nil`) and a custom `init` that, when editing, seeds `_metadata = State(initialValue: <mapped from document>)` and `_scannedImages = State(initialValue: <pre-rendered pages>)`.
- **Guard `onAppear`:** only assign `defaultName` and seed `scannedImages` from `preview` in **create** mode. In edit mode the state is already seeded by the init; running the create-mode `onAppear` would clobber the real name and re-seed images.
- Nav title: keep `Document Details` for create; use an "Edit" title for edit mode (reuse `L10n.Common.edit` or add `documents.metadata.editTitle`). Save button label may stay "Save Document" or use a generic Save — minor.
- All form sections (category, specialization, date, name, doctor, notes, preview) are **unchanged** and shared between modes.
- `onSave: (DocumentMetadata, DocumentPreviewContent) -> Void` signature unchanged — it already carries the edited metadata and the (possibly edited) pages.

### 2. PDF→images rendering

Add a renderer (in `PDFGenerator` or `DocumentFileManager`):

```swift
func renderPages(from url: URL) -> [UIImage]   // one UIImage per PDF page
```

Implementation: open `PDFDocument(url:)`, for each page render to a `UIImage` via `UIGraphicsImageRenderer` at the page's bounds (or `page.thumbnail(of:for:)` at a reasonable resolution). Used to seed the page editor for `.scan` documents.

### 3. Preview source per type (decided when Edit is tapped)

- `.scan` → `.scannedImages(renderPages(from: fileURL))` — full page editor.
- `.image` → `.scannedImages([loadImage(url:)])` — editable; adding pages promotes it to a multi-page PDF.
- `.pdf` (imported) → `.importedFile(fileURL)` — read-only file row, metadata-only.

Rendering is I/O; perform it off the main thread with a brief loading state before presenting the form (see §4).

### 4. `DocumentViewerView` — menu + stale-state fix

- **Menu:** replace the Rename `Button` (and remove the `showRename`/`renameText` alert) with:
  ```swift
  Button { startEdit() } label: { Label(L10n.Common.edit, systemImage: "pencil") }
  ```
- **Staleness fix (latent bug):** change `let document: Document` to `@State private var document: Document`, seeded from an init parameter. On edit-save, apply the returned metadata (and any type/filename change) to this local copy so the header and info sheet refresh immediately.
- **File reload:** add a `refreshID` (e.g. `@State private var refreshID = UUID()`) applied as `.id(refreshID)` to the PDF/image content view; bump it after a page edit so the overwritten file (same path) is reloaded rather than served from PDFKit's cache.
- **API change:** replace `onRename: ((String) -> Void)?` with `onEdit: ((DocumentMetadata, DocumentPreviewContent) -> Void)?`.
- **Flow:** `startEdit()` determines the preview by type (rendering pages off-main with a loading indicator for `.scan`), then presents `DocumentMetadataView(editingDocument: document, preview: <preview>) { metadata, preview in /* update local copy + call onEdit */ }` via `.sheet`.

### 5. `DocumentFileManager` — in-place file replacement

- `func replacePDF(from images: [UIImage], documentID: UUID) throws -> URL` — overwrites `{id}.pdf` (atomic write, **no** duplicate guard). Returns the file URL.
- `func replaceImage(_ image: UIImage, documentID: UUID) throws -> URL` — overwrites `{id}.jpg` for the single-image-unchanged-count case (optional; only if the image was re-scanned).
- **Image→multi-page promotion:** when an `.image` document gains pages, write a new `{id}.pdf`, delete the old `{id}.jpg`, and report the new extension/type so the ViewModel can rebuild the `Document` with the new `documentType`/`filename`.

### 6. `DocumentsListViewModel` — `updateDocument`

```swift
func updateDocument(_ document: Document,
                    metadata: DocumentMetadata,
                    preview: DocumentPreviewContent)
```

Behavior:
1. Find the existing document by `id`. (Bail if not found.)
2. Apply metadata back to the document using the field mapping above (`createdAt`, `category`, `specialization`, `doctorName`, `notes`, `tags`/`customFolderId`, `name`).
3. If `preview` is `.scannedImages` **and** the pages changed:
   - `.scan` doc → `replacePDF(from: images, documentID: id)`; `filename`/`documentType` unchanged.
   - `.image` doc that now has >1 page (or page replaced) → write PDF, delete old jpg, rebuild `Document` (same `id`) with `documentType = .scan` and the new `.pdf` filename.
   - File bytes changed → also `enqueueUpload(...)` for sync (in addition to metadata update).
4. If `.importedFile` (imported PDF) → metadata only, no file rewrite.
5. Replace the element in `documents` (preserving order), `persistMetadata()`, and `SyncQueueManager.shared.enqueueMetadataUpdate(updated)`.
6. **Do not** call `recordUpload()` (this is an edit, not a new upload).

Detecting "pages changed": compare new image count to the document's existing `pageCount`, and treat any re-scan as changed. A pragmatic v1 rule: if `.scannedImages`, always re-save (correct, slightly wasteful). The plan may refine to a content/count check.

### 7. Wiring in `DocsView`

In `navigationDestination(for: Document.self)`, replace the `onRename:` closure with:

```swift
DocumentViewerView(
    document: document,
    onDelete: { viewModel.deleteDocument(document) },
    onEdit: { metadata, preview in
        viewModel.updateDocument(document, metadata: metadata, preview: preview)
    }
)
```

## Data flow

1. User opens a document → `DocumentViewerView` (now holds `@State document`).
2. Taps ⋯ → **Edit**.
3. `startEdit()` builds the preview by type (renders pages off-main for `.scan`, shows loading).
4. `DocumentMetadataView` presents in edit mode, pre-filled.
5. User edits metadata and/or pages, taps Save → `onSave(metadata, preview)`.
6. Viewer applies metadata to its local `document`, bumps `refreshID`, and calls `onEdit`.
7. `DocsView` calls `viewModel.updateDocument(...)` → file re-saved in place if needed → `persistMetadata()` + sync enqueue → `documents` array updated.

## Error handling

- Reuse the existing `errorMessage` pattern on the ViewModel for file re-save failures (`DocumentFileError`).
- If `renderPages` returns empty (corrupt PDF), fall back to metadata-only preview (`.importedFile`) rather than presenting an empty page editor.
- `updateDocument` bails silently if the document id is no longer in `documents` (e.g. deleted meanwhile).

## Testing / verification

No test target exists. Verify by:

- `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build` succeeds.
- Manual smoke (document each):
  - Edit metadata only on a scan, an image, and an imported PDF → values persist and the viewer refreshes without re-navigating.
  - Add and remove pages on a scan → file updates, page count changes.
  - Add a page to a single image → it becomes a multi-page PDF (type/filename migrate), still opens correctly.
  - Cancel an edit → no changes.
  - Re-scan flow inside edit works (the existing `showScanner` path).

## Risks / notes

- Camera scanning requires a physical device; the "add pages" path can't be fully exercised in the simulator.
- Re-rendering a `.scan` PDF to images and back is mildly lossy (re-JPEG), acceptable since scans are already raster.
- PDFKit may cache the rendered file at a given URL; the `refreshID` `.id()` bump addresses stale display after in-place overwrite.
