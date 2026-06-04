# Edit Uploaded Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an **Edit** action to the document viewer's three-dot menu (replacing Rename) that reuses the upload form to edit a document's metadata, plus a full page editor (add/remove/re-scan) for scans and images.

**Architecture:** Extend `DocumentMetadataView` with an optional edit mode (custom init seeds the form state from an existing `Document`). The viewer holds the document as `@State` and refreshes in place after save. A new `DocumentsListViewModel.updateDocument` persists metadata and, when pages changed, re-saves the file in place via new in-place `DocumentFileManager` methods. Imported PDFs stay metadata-only.

**Tech Stack:** SwiftUI, PDFKit, UIKit (UIGraphicsImageRenderer), MVVM. No SPM/CocoaPods. No test target — verification is `xcodebuild` + manual smoke notes.

---

## Notes for the implementer (read first)

- **No test target exists.** Do not create one. "Verify" steps mean: run the build command below and confirm it succeeds, then perform the named manual smoke check on a simulator/device.
- **Build command** (use everywhere a step says "build"):
  ```bash
  xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
  ```
  Expected: `** BUILD SUCCEEDED **`. Camera scanning ("add pages") requires a physical device and can't be fully exercised in the simulator — note that where relevant.
- **Design system:** use named tokens only (`Color.surfaceWhite`, `.accent`, `Font.bodyL`, etc.), never raw hex. Match the surrounding file's style.
- **Filesystem-based Xcode sync:** new Swift files in the right folder are auto-detected; no `.pbxproj` editing needed.
- **Commit after each task.** This branch is `feature/new-onboarding`; commit there unless told otherwise. End commit messages with the Co-Authored-By trailer:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  ```
- **Field mapping `Document` ⇄ `DocumentMetadata`** (used in Tasks 3 & 5):

  | DocumentMetadata | Document | Seed (Doc→Meta) | Save back (Meta→Doc) |
  |---|---|---|---|
  | `name` | `name` | direct | trimmed |
  | `category` | `category` | direct | direct |
  | `customFolderId: UUID?` | `tags: [String]?` | first element parseable as `UUID` | `tags = id.map { [$0.uuidString] }` |
  | `specialization` (non-opt) | `specialization?` | `?? .other` | store non-nil |
  | `doctorName: String` | `doctorName: String?` | `?? ""` | trimmed; `""` → `nil` |
  | `notes: String` | `notes: String?` | `?? ""` | trimmed; `""` → `nil` |
  | `documentDate` | `createdAt` | direct | direct |

---

## Task 1: PDF→images renderer in PDFGenerator

**Files:**
- Modify: `Neura/Core/Services/PDFGenerator.swift`

- [ ] **Step 1: Read the existing file**

Read `Neura/Core/Services/PDFGenerator.swift` in full to match its style (`final class`, `static let shared`, method placement).

- [ ] **Step 2: Add a `renderImages(from:)` method**

Add this method inside the `PDFGenerator` class (after `generatePDF(from:)`):

```swift
/// Render each page of a PDF file to a UIImage. Returns [] if the file
/// can't be opened. Used to seed the page editor when editing a scan.
func renderImages(from url: URL, maxDimension: CGFloat = 2000) -> [UIImage] {
    guard let pdf = PDFDocument(url: url) else { return [] }
    var images: [UIImage] = []
    for index in 0..<pdf.pageCount {
        guard let page = pdf.page(at: index) else { continue }
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { continue }

        // Scale so the longest side is at most maxDimension.
        let scale = min(1, maxDimension / max(pageRect.width, pageRect.height))
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        images.append(image)
    }
    return images
}
```

Ensure the file imports `UIKit` and `PDFKit` (add `import UIKit` / `import PDFKit` at the top if missing).

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/PDFGenerator.swift
git commit -m "feat: add PDF page-to-image renderer for document editing

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: In-place file replacement in DocumentFileManager

**Files:**
- Modify: `Neura/Core/Services/DocumentFileManager.swift`

These methods overwrite the existing file for a known document id (no duplicate guard), and handle the image→multi-page-PDF promotion. They return the resulting file URL so the ViewModel can update `filename`.

- [ ] **Step 1: Add `replacePDF(from:documentID:)`**

Add inside the `// MARK: - Save PDF` section, after `savePDF(from:name:documentID:)`:

```swift
/// Overwrite the PDF file for an existing document id (no duplicate guard).
/// Returns the file URL. Used when editing a scanned document's pages.
@discardableResult
func replacePDF(from images: [UIImage], documentID: UUID) throws -> URL {
    guard let pdfDocument = PDFGenerator.shared.generatePDF(from: images) else {
        throw DocumentFileError.pdfGenerationFailed
    }
    let filename = "\(documentID.uuidString).pdf"
    let fileURL = baseScanDirectory.appendingPathComponent(filename)
    guard pdfDocument.write(to: fileURL) else {
        throw DocumentFileError.pdfSaveFailed
    }
    return fileURL
}
```

- [ ] **Step 2: Add `replaceImage(_:documentID:)`**

Add inside the `// MARK: - Save Image` section, after `saveImage(_:name:documentID:)`:

```swift
/// Overwrite the JPEG file for an existing single-image document id
/// (no duplicate guard). Returns the file URL.
@discardableResult
func replaceImage(_ image: UIImage, documentID: UUID) throws -> URL {
    guard let imageData = image.jpegData(compressionQuality: 0.85) else {
        throw DocumentFileError.imageConversionFailed
    }
    let filename = "\(documentID.uuidString).jpg"
    let fileURL = baseScanDirectory.appendingPathComponent(filename)
    try imageData.write(to: fileURL, options: .atomic)
    return fileURL
}
```

- [ ] **Step 3: Add `promoteImageToPDF(from:documentID:)`**

Add after `replacePDF(...)`. This handles a single-image document that gained pages: write the PDF, delete the stale `.jpg`.

```swift
/// Convert a former single-image document into a multi-page PDF: write the
/// new PDF and delete the old JPEG. Returns the new PDF file URL. The caller
/// must update the document's `filename` and `documentType` (now `.scan`).
@discardableResult
func promoteImageToPDF(from images: [UIImage], documentID: UUID) throws -> URL {
    let pdfURL = try replacePDF(from: images, documentID: documentID)
    let jpgURL = baseScanDirectory.appendingPathComponent("\(documentID.uuidString).jpg")
    if fileManager.fileExists(atPath: jpgURL.path) {
        try? fileManager.removeItem(at: jpgURL)
    }
    return pdfURL
}
```

- [ ] **Step 4: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Neura/Core/Services/DocumentFileManager.swift
git commit -m "feat: in-place file replacement for document editing

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Edit mode in DocumentMetadataView

**Files:**
- Modify: `Neura/Features/Documents/Views/Components/ScanDocumentView.swift`

Add an optional `editingDocument` to the form; when present, seed the form state from it and skip the create-mode `onAppear` defaulting.

- [ ] **Step 1: Add the stored property and custom init**

In `struct DocumentMetadataView`, after the existing stored properties `let preview` / `let onSave`, add:

```swift
    /// Non-nil when editing an existing document (pre-fills the form).
    let editingDocument: Document?
```

Then add a custom initializer (place it right after the `@FocusState` / `Field` declarations, before `var body`). It seeds `metadata` and `scannedImages` when editing:

```swift
    init(
        preview: DocumentPreviewContent,
        editingDocument: Document? = nil,
        onSave: @escaping (DocumentMetadata, DocumentPreviewContent) -> Void
    ) {
        self.preview = preview
        self.editingDocument = editingDocument
        self.onSave = onSave

        if let doc = editingDocument {
            var meta = DocumentMetadata()
            meta.name = doc.name
            meta.category = doc.category
            meta.customFolderId = doc.tags?
                .compactMap { UUID(uuidString: $0) }
                .first
            meta.specialization = doc.specialization ?? .other
            meta.doctorName = doc.doctorName ?? ""
            meta.notes = doc.notes ?? ""
            meta.documentDate = doc.createdAt
            _metadata = State(initialValue: meta)

            if case .scannedImages(let images) = preview {
                _scannedImages = State(initialValue: images)
            }
        }
    }
```

> Note: the two existing `#Preview` blocks call `DocumentMetadataView(preview:onSave:)` — they still compile because `editingDocument` defaults to `nil`.

- [ ] **Step 2: Guard the create-mode `onAppear`**

The current `onAppear` (around line 81) is:

```swift
            .onAppear {
                if case .scannedImages(let images) = preview {
                    scannedImages = images
                }
                metadata.name = defaultName
            }
```

Replace it with a version that does nothing in edit mode (state is already seeded by the init):

```swift
            .onAppear {
                guard editingDocument == nil else { return }
                if case .scannedImages(let images) = preview {
                    scannedImages = images
                }
                metadata.name = defaultName
            }
```

- [ ] **Step 3: Set an edit-mode nav title**

The current modifier is `.navigationTitle(L10n.Documents.Metadata.title)`. Replace with:

```swift
            .navigationTitle(editingDocument == nil ? L10n.Documents.Metadata.title : L10n.Common.edit)
```

(`L10n.Common.edit` already exists = "Edit".)

- [ ] **Step 4: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. Both `#Preview`s still compile.

- [ ] **Step 5: Commit**

```bash
git add Neura/Features/Documents/Views/Components/ScanDocumentView.swift
git commit -m "feat: edit mode for DocumentMetadataView (pre-fill from document)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: updateDocument in DocumentsListViewModel

**Files:**
- Modify: `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`

Add the persistence method that applies edited metadata and, when `.scannedImages` is supplied, re-saves the file in place (with image→PDF promotion). Model it on `renameDocument` — synchronous, on the main actor, then persist + enqueue.

- [ ] **Step 1: Read the file**

Read `DocumentsListViewModel.swift`, focusing on `saveDocument`, `renameDocument`, `deleteDocument`, and `persistMetadata` to match conventions and confirm `SyncQueueManager` method names (`enqueueMetadataUpdate`, `enqueueUpload`).

- [ ] **Step 2: Add `updateDocument`**

Add near `renameDocument`:

```swift
func updateDocument(_ document: Document,
                    metadata: DocumentMetadata,
                    preview: DocumentPreviewContent) {
    guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
    var updated = documents[index]

    // Apply metadata (see field-mapping table in the plan).
    updated.name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
    updated.createdAt = metadata.documentDate
    updated.category = metadata.category
    updated.specialization = metadata.specialization
    let doctor = metadata.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
    updated.doctorName = doctor.isEmpty ? nil : doctor
    let notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    updated.notes = notes.isEmpty ? nil : notes
    updated.tags = metadata.customFolderId.map { [$0.uuidString] }

    var fileBytesChanged = false

    // Re-save the file in place when pages were supplied (scans/images only).
    if case .scannedImages(let images) = preview, !images.isEmpty {
        do {
            let fm = DocumentFileManager.shared
            if updated.documentType == .image && images.count > 1 {
                // Single image gained pages -> becomes a multi-page PDF.
                let url = try fm.promoteImageToPDF(from: images, documentID: updated.id)
                updated = Document(
                    id: updated.id,
                    name: updated.name,
                    fileURL: url,
                    createdAt: updated.createdAt,
                    documentType: .scan,
                    category: updated.category,
                    specialization: updated.specialization,
                    doctorName: updated.doctorName,
                    notes: updated.notes,
                    tags: updated.tags
                )
            } else if updated.documentType == .image {
                try fm.replaceImage(images[0], documentID: updated.id)
            } else {
                try fm.replacePDF(from: images, documentID: updated.id)
            }
            fileBytesChanged = true
        } catch {
            errorMessage = "Failed to update document: \(error.localizedDescription)"
            return
        }
    }

    documents[index] = updated
    persistMetadata()
    SyncQueueManager.shared.enqueueMetadataUpdate(updated)
    if fileBytesChanged {
        SyncQueueManager.shared.enqueueUpload(updated)
    }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}
```

> Verify the `Document` initializer parameter order/labels against `Neura/Core/Models/Document.swift` (init at ~line 154) and adjust if they differ. Do **not** call `recordUpload()` — this is an edit, not a new upload.

- [ ] **Step 3: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift
git commit -m "feat: updateDocument for editing metadata and pages in place

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Edit action + in-place refresh in DocumentViewerView

**Files:**
- Modify: `Neura/Features/Documents/Views/Components/DocumentViewerView.swift`

Replace Rename with Edit, hold the document as `@State`, prepare the per-type preview, present the edit form, and refresh after save.

- [ ] **Step 1: Change stored `document` to `@State` + add edit state**

Current declarations (top of `struct DocumentViewerView`):

```swift
    let document: Document
    let onDelete: () -> Void
    var onRename: ((String) -> Void)?
```

Replace with:

```swift
    let onDelete: () -> Void
    var onEdit: ((DocumentMetadata, DocumentPreviewContent) -> Void)?

    @State private var document: Document
    @State private var showEditSheet = false
    @State private var editPreview: DocumentPreviewContent?
    @State private var isPreparingEdit = false
    @State private var contentRefreshID = UUID()

    init(document: Document,
         onDelete: @escaping () -> Void,
         onEdit: ((DocumentMetadata, DocumentPreviewContent) -> Void)? = nil) {
        _document = State(initialValue: document)
        self.onDelete = onDelete
        self.onEdit = onEdit
    }
```

Then **remove** the now-unused rename state declarations:

```swift
    @State private var showRename = false
    @State private var renameText = ""
```

- [ ] **Step 2: Replace the Rename menu item with Edit**

In the `Menu { ... }` (around line 115), replace the Rename button:

```swift
                Button {
                    renameText = document.name
                    showRename = true
                } label: {
                    Label(L10n.Common.rename, systemImage: "pencil")
                }
```

with:

```swift
                Button {
                    startEdit()
                } label: {
                    Label(L10n.Common.edit, systemImage: "pencil")
                }
```

- [ ] **Step 3: Remove the rename alert, add the edit sheet + loading overlay**

Delete the rename alert modifier (around lines 64–75):

```swift
        .alert(L10n.Documents.Viewer.renameTitle, isPresented: $showRename) {
            TextField(L10n.Documents.Viewer.renamePlaceholder, text: $renameText)
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.save) {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onRename?(trimmed)
                }
            }
        } message: {
            Text(L10n.Documents.Viewer.renameMessage)
        }
```

Add this `.sheet` next to the other sheets (e.g. after the `showInfo` sheet):

```swift
        .sheet(isPresented: $showEditSheet) {
            if let preview = editPreview {
                DocumentMetadataView(
                    preview: preview,
                    editingDocument: document
                ) { metadata, updatedPreview in
                    applyEdit(metadata: metadata, preview: updatedPreview)
                }
            }
        }
```

Add a loading overlay for page rendering. Attach to the root `VStack`'s `.overlay` (place near the existing `.onAppear`):

```swift
        .overlay {
            if isPreparingEdit {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(Color.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
```

- [ ] **Step 4: Add `.id(contentRefreshID)` to the content view**

In the content `ZStack` (around lines 30–48), add `.id(contentRefreshID)` to the PDF/image branch so an in-place file overwrite forces a reload. Apply it to the whole content `ZStack`:

```swift
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if !document.fileExists {
                    fileMissingView
                } else if document.isPDF {
                    PDFDocumentView(url: document.fileURL)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                } else if document.isImage {
                    ImageDocumentView(url: document.fileURL)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                }
            }
            .id(contentRefreshID)
            .opacity(appear ? 1 : 0)
```

- [ ] **Step 5: Add `startEdit()` and `applyEdit(...)` helpers**

Add these methods to the `private extension DocumentViewerView` (alongside `shareDocument()`):

```swift
    func startEdit() {
        switch document.documentType {
        case .pdf:
            // Imported PDF -> metadata only, read-only file row.
            editPreview = .importedFile(document.fileURL)
            showEditSheet = true
        case .image:
            if let image = try? DocumentFileManager.shared.loadImage(url: document.fileURL) {
                editPreview = .scannedImages([image])
            } else {
                editPreview = .importedFile(document.fileURL)
            }
            showEditSheet = true
        case .scan:
            isPreparingEdit = true
            let url = document.fileURL
            DispatchQueue.global(qos: .userInitiated).async {
                let images = PDFGenerator.shared.renderImages(from: url)
                DispatchQueue.main.async {
                    isPreparingEdit = false
                    // Fall back to metadata-only if rendering failed.
                    editPreview = images.isEmpty ? .importedFile(url) : .scannedImages(images)
                    showEditSheet = true
                }
            }
        }
    }

    func applyEdit(metadata: DocumentMetadata, preview: DocumentPreviewContent) {
        // Optimistically refresh the local copy so the header/info update now.
        document.name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
        document.createdAt = metadata.documentDate
        document.category = metadata.category
        document.specialization = metadata.specialization
        let doctor = metadata.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.doctorName = doctor.isEmpty ? nil : doctor
        let notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        document.notes = notes.isEmpty ? nil : notes
        document.tags = metadata.customFolderId.map { [$0.uuidString] }

        // Persist (and re-save file if pages changed) via the ViewModel.
        onEdit?(metadata, preview)

        // Force the PDF/image view to reload the (possibly overwritten) file.
        contentRefreshID = UUID()
    }
```

> Note: `applyEdit` does not migrate the local `documentType`/`filename` for the image→PDF case; the on-disk file at the same id path is overwritten and `contentRefreshID` reloads it. The authoritative `documentType` update lives in the ViewModel's `documents` array and is reflected on next navigation. If the viewer must show the promoted type immediately, that is a follow-up — out of scope for v1.

- [ ] **Step 6: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. Fix any references to the removed `onRename`/`showRename`/`renameText` (there should be none left in this file).

- [ ] **Step 7: Commit**

```bash
git add Neura/Features/Documents/Views/Components/DocumentViewerView.swift
git commit -m "feat: Edit action in document viewer (replaces Rename) with in-place refresh

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Wire the viewer in DocsView

**Files:**
- Modify: `Neura/Features/Documents/Views/DocsView.swift:153-159`

- [ ] **Step 1: Replace the `onRename` wiring with `onEdit`**

Current `navigationDestination(for: Document.self)`:

```swift
        .navigationDestination(for: Document.self) { document in
            DocumentViewerView(document: document, onDelete: {
                viewModel.deleteDocument(document)
            }, onRename: { newName in
                viewModel.renameDocument(document, to: newName)
            })
        }
```

Replace with:

```swift
        .navigationDestination(for: Document.self) { document in
            DocumentViewerView(document: document, onDelete: {
                viewModel.deleteDocument(document)
            }, onEdit: { metadata, preview in
                viewModel.updateDocument(document, metadata: metadata, preview: preview)
            })
        }
```

- [ ] **Step 2: Check for other DocumentViewerView call sites**

Run:

```bash
grep -rn "DocumentViewerView(" Neura --include="*.swift"
```

For every call site still passing `onRename:`, replace it with the `onEdit:` form above (calling `viewModel.updateDocument`). Likely also in `CategoryDocumentsView` and `CustomFolderDocumentsView` if they present the viewer. If a call site has no ViewModel handy, pass the same `viewModel.updateDocument` closure used by its surrounding list.

- [ ] **Step 3: Check for other `renameDocument` usages**

Run:

```bash
grep -rn "renameDocument\|onRename" Neura --include="*.swift"
```

If `renameDocument` is now unreferenced, leave it in place (harmless) or remove it if the project prefers no dead code — implementer's call; do not remove if any other feature uses it.

- [ ] **Step 4: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: wire Edit action to updateDocument across document viewer call sites

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Manual smoke verification

**Files:** none (verification only)

- [ ] **Step 1: Build and launch on a simulator**

Run the build command, then run the app on iPhone 16 simulator.

- [ ] **Step 2: Metadata-only edits**

For a scanned doc, an imported PDF, and a single image already in the library:
- Open it → ⋯ → **Edit**. Confirm the form opens pre-filled with the correct name, category, specialization, date, doctor, notes.
- Change the name and category → Save. Confirm the viewer header updates **immediately** (no need to go back and re-open), and the Info sheet shows new values.
- Confirm the document list reflects the change.

Expected: all three types editable; imported PDF shows the read-only file row (no page thumbnails).

- [ ] **Step 3: Page edits on a scan (remove)**

Open a multi-page scan → Edit → remove a page → Save. Confirm the PDF in the viewer reloads with fewer pages (the `contentRefreshID` reload).

- [ ] **Step 4: Page edits on a scan (add) — physical device**

On a device, open a scan → Edit → "add more pages" → scan a page → Save. Confirm the page count increases and the file persists across app relaunch.

- [ ] **Step 5: Image → multi-page promotion — physical device**

Open a single image → Edit → add a page → Save. Confirm it becomes a PDF (navigate away and back so the array-backed `documentType` is reflected) and opens correctly; the old `.jpg` is gone.

- [ ] **Step 6: Cancel path**

Open any doc → Edit → change fields → Cancel. Confirm nothing changed.

- [ ] **Step 7: Record results**

Write a short note in the PR/commit describing what was verified on simulator vs device (camera-dependent steps can only be confirmed on device).

---

## Self-review (completed during planning)

- **Spec coverage:** Renderer (Task 1), in-place file replacement incl. image→PDF (Task 2), edit-mode form with field mapping (Task 3), `updateDocument` persistence/sync (Task 4), Edit-replaces-Rename + staleness fix + `refreshID` + per-type preview (Task 5), DocsView/other call-site wiring (Task 6), verification incl. all spec smoke cases (Task 7). All spec sections map to a task.
- **Placeholders:** none — every code step shows full code; verification steps name exact actions.
- **Type consistency:** `renderImages(from:)`, `replacePDF(from:documentID:)`, `replaceImage(_:documentID:)`, `promoteImageToPDF(from:documentID:)`, `updateDocument(_:metadata:preview:)`, `onEdit: ((DocumentMetadata, DocumentPreviewContent) -> Void)?`, `editingDocument`, `contentRefreshID`, `startEdit()`, `applyEdit(metadata:preview:)` are used consistently across tasks.
- **Known follow-up (out of v1 scope):** the viewer's local `documentType`/`filename` is not migrated for the image→PDF case until next navigation (Task 5 Step 5 note); verified acceptable in the spec.
