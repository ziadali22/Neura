# Google Drive Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4th "Import from Google Drive" entry point to the existing Add Document sheet that opens the same system file picker already used by "Import File," with a one-time tip guiding users to Drive inside it.

**Architecture:** No OAuth, no Drive REST API, no custom Drive browser. The new button reuses the existing `.fileImporter`-based pipeline end to end (`handleFileImport` → `pendingPreview = .importedFile(url)` → `DocumentMetadataView` → `saveDocument`). The only new pieces are: a 4th row in `AddDocumentSheet`, a one-time educational `.alert` in `DocsView`, and a thin `startGoogleDriveImport()` / `confirmDriveImportTip()` pair in `DocumentsListViewModel` that gates the tip on a `UserDefaults` flag before flipping the same `showFileImporter` bool the "Files" button already uses.

**Tech Stack:** SwiftUI, `UIDocumentPickerViewController` (via `.fileImporter`), `UserDefaults`, the existing `L10n` string system (`L10n_swift` package, `.l10n()` extension).

**Design spec:** `docs/superpowers/specs/2026-07-10-google-drive-import-design.md`

## Global Constraints

- No test target exists in this project (per `CLAUDE.md`) — every task's verification step is a build check (`xcodebuild build`) plus, where noted, a manual simulator/device check. There is no automated test suite to run.
- No changes to `Document.swift`, `DocumentFileManager`, or any storage/model code — Drive-imported files are stored identically to any other imported file.
- No OAuth, no `GIDSignIn` Drive scopes, no `GTLRDrive`/Drive REST calls, no custom in-app file browser.
- All new user-facing alert strings must go through `L10n` (title/message/button) and be added to all three locale files: `Neura/Core/L10n/en.lproj/Localizable.strings`, `Neura/Core/L10n/ar.lproj/Localizable.strings`, `Neura/Core/L10n/ro.lproj/Localizable.strings`. This matches `DocsView.swift`'s existing alerts, which are 100% L10n-driven.
- The new row's title/subtitle in `AddDocumentSheet.swift` stay as hardcoded English string literals, matching that specific file's existing convention (its other 3 rows are hardcoded despite unused `L10n.Documents.AddDocument.scanSubtitle`/`photoSubtitle`/`fileSubtitle` keys already sitting in `L10n.swift`) — do not "fix" that pre-existing inconsistency as part of this feature; it's out of scope.
- Key naming convention for new `L10n` keys: `documents.<subGroupCamelCase>.<propertyCamelCase>` (e.g. `documents.googleDriveImport.tipTitle`), matching the existing `documents.photoAccess.title` pattern exactly.
- `UserDefaults` key naming convention in this file: dot-namespaced strings like `"docs.displayMode"` (see `DocumentsListViewModel.swift:36`). The new key must follow this: `"docs.hasSeenDriveImportTip"`.

---

### Task 1: Google Drive icon asset + 4th row in `AddDocumentSheet`

**Files:**
- Create: `Neura/Resources/Assets.xcassets/google-drive.imageset/Contents.json`
- Create (manual asset sourcing — see Step 1): `Neura/Resources/Assets.xcassets/google-drive.imageset/google-drive.png`, `google-drive@2x.png`, `google-drive@3x.png`
- Modify: `Neura/Features/Documents/Views/Components/AddDocumentSheet.swift`

**Interfaces:**
- Produces: `AddDocumentSheet` now requires a 4th initializer parameter `onGoogleDrive: () -> Void`. Every call site must be updated (there are exactly two: `DocsView.swift:31` and the `#Preview` at the bottom of `AddDocumentSheet.swift` itself — both handled in Task 4 and this task respectively).
- Produces: `optionRow(icon:title:subtitle:isSymbolIcon:action:)` gains a new `isSymbolIcon: Bool = true` parameter. Existing 3 call sites are unaffected (default `true` preserves current behavior exactly); the new Drive row passes `isSymbolIcon: false`.

- [ ] **Step 1: Source the Google Drive logo asset**

This step requires an actual image file that cannot be generated from text — obtain the official multi-color Google Drive triangle logo (e.g. from Google's published Drive product icon/brand resources) as a raster image, and export it at three sizes:
- `google-drive.png` — 25×25 px (1x)
- `google-drive@2x.png` — 50×50 px (2x)
- `google-drive@3x.png` — 75×75 px (3x)

Place all three files directly in a new folder `Neura/Resources/Assets.xcassets/google-drive.imageset/` (create the folder if it doesn't exist). Do not proceed to Step 2 until these three files exist at that exact path — Xcode's asset catalog will fail to compile the asset otherwise.

- [ ] **Step 2: Create the imageset's `Contents.json`**

Create `Neura/Resources/Assets.xcassets/google-drive.imageset/Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "google-drive.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "google-drive@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "google-drive@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "original"
  }
}
```

The `"template-rendering-intent": "original"` property guarantees SwiftUI renders this asset in its native brand colors and ignores any `.foregroundStyle()` tint applied elsewhere — this matters because `optionRow`'s icon circle currently applies `.foregroundStyle(Color.accent)` unconditionally.

- [ ] **Step 3: Update `optionRow` to support full-color raster icons**

The existing `scanAdd`/`imageAdd`/`fileAdd` icons are single-color vector assets sized via `.font(.system(size: 25))` (SwiftUI's symbol-image sizing, which only works for template/vector assets). The new Google Drive logo is a full-color raster PNG, which `.font()` cannot size — it needs `.resizable().scaledToFit().frame(...)` instead. Add a parameter to switch between the two rendering paths without touching the existing three rows' behavior.

In `Neura/Features/Documents/Views/Components/AddDocumentSheet.swift`, replace the `optionRow` function (currently lines 35-65):

```swift
    private func optionRow(icon: String, title: String, subtitle: String, isSymbolIcon: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color(hex: "E7E0D8").opacity(0.4))
                    .frame(width: 52, height: 52)
                    .overlay {
                        if isSymbolIcon {
                            Image(icon)
                                .font(.system(size: 25))
                                .foregroundStyle(Color.accent)
                        } else {
                            Image(icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                        }
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
```

- [ ] **Step 4: Add the `onGoogleDrive` parameter and 4th row**

In the same file, replace the top of the struct (currently lines 3-33):

```swift
struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: () -> Void
    let onPhoto: () -> Void
    let onFile: () -> Void
    let onGoogleDrive: () -> Void

    private struct Option {
        let icon: String
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.stroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            optionRow(icon: "scanAdd",   title: "Scan Document",      subtitle: "Use camera to scan pages")           { dismiss(); onScan() }
            Divider().padding(.leading, 76)
            optionRow(icon: "imageAdd",  title: "Upload from Photos", subtitle: "Choose an image from your library") { dismiss(); onPhoto() }
            Divider().padding(.leading, 76)
            optionRow(icon: "fileAdd",   title: "Import File",        subtitle: "Select a PDF or image file")         { dismiss(); onFile() }
            Divider().padding(.leading, 76)
            optionRow(icon: "google-drive", title: "Import from Google Drive", subtitle: "Bring in a file from your Drive", isSymbolIcon: false) { dismiss(); onGoogleDrive() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }
```

- [ ] **Step 5: Update the `#Preview`**

Replace the file's `#Preview` block (currently lines 68-71):

```swift
#Preview {
    AddDocumentSheet(onScan: {}, onPhoto: {}, onFile: {}, onGoogleDrive: {})
        .presentationDetents([.height(350)])
}
```

- [ ] **Step 6: Verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

Expected: Build fails with an error at `DocsView.swift:31` (`AddDocumentSheet` call missing the `onGoogleDrive` argument) — this is expected since Task 4 hasn't run yet. Confirm the *only* error is that missing-argument error, and that there are no errors inside `AddDocumentSheet.swift` itself (e.g. no "cannot find 'google-drive' in asset catalog" or icon-rendering errors). If there are errors inside `AddDocumentSheet.swift`, fix them before proceeding.

- [ ] **Step 7: Commit**

```bash
git add Neura/Resources/Assets.xcassets/google-drive.imageset Neura/Features/Documents/Views/Components/AddDocumentSheet.swift
git commit -m "Add Google Drive icon asset and 4th row to AddDocumentSheet"
```

---

### Task 2: Add L10n strings for the Drive import tip

**Files:**
- Modify: `Neura/Core/L10n/L10n.swift:473-477` (insert new enum after `AddDocument`, before `CategoryPicker`)
- Modify: `Neura/Core/L10n/en.lproj/Localizable.strings` (near line 262, after `documents.photoAccess.message`)
- Modify: `Neura/Core/L10n/ar.lproj/Localizable.strings` (near line 257, after `documents.photoAccess.message`)
- Modify: `Neura/Core/L10n/ro.lproj/Localizable.strings` (near line 257, after `documents.photoAccess.message`)

**Interfaces:**
- Produces: `L10n.Documents.GoogleDriveImport.tipTitle`, `L10n.Documents.GoogleDriveImport.tipMessage`, `L10n.Documents.GoogleDriveImport.tipContinue` — all `static var String`. Task 4 consumes these exact names.

- [ ] **Step 1: Add the Swift enum**

In `Neura/Core/L10n/L10n.swift`, find this existing block (lines 473-477):

```swift
        enum AddDocument {
            static var scanSubtitle: String { "documents.addDocument.scanSubtitle".l10n() }
            static var photoSubtitle: String { "documents.addDocument.photoSubtitle".l10n() }
            static var fileSubtitle: String { "documents.addDocument.fileSubtitle".l10n() }
        }
```

Insert immediately after it (before `enum CategoryPicker {`):

```swift

        enum GoogleDriveImport {
            static var tipTitle: String { "documents.googleDriveImport.tipTitle".l10n() }
            static var tipMessage: String { "documents.googleDriveImport.tipMessage".l10n() }
            static var tipContinue: String { "documents.googleDriveImport.tipContinue".l10n() }
        }
```

- [ ] **Step 2: Add English strings**

In `Neura/Core/L10n/en.lproj/Localizable.strings`, find:

```
"documents.photoAccess.message" = "Neura needs access to your photo library to upload images. Please allow access in Settings.";
```

Insert immediately after it:

```
"documents.googleDriveImport.tipTitle" = "Importing from Google Drive";
"documents.googleDriveImport.tipMessage" = "In the browser that opens, tap Browse, then Locations, then Google Drive. If you don't see it, install the Google Drive app and sign in first.";
"documents.googleDriveImport.tipContinue" = "Continue";
```

- [ ] **Step 3: Add Arabic strings**

In `Neura/Core/L10n/ar.lproj/Localizable.strings`, find:

```
"documents.photoAccess.message" = "يحتاج Neura إلى الوصول إلى مكتبة صورك لرفع الصور. يُرجى السماح بالوصول من الإعدادات.";
```

Insert immediately after it:

```
"documents.googleDriveImport.tipTitle" = "الاستيراد من Google Drive";
"documents.googleDriveImport.tipMessage" = "في المتصفح الذي يفتح، اضغط على تصفح، ثم المواقع، ثم Google Drive. إذا لم تجده، ثبّت تطبيق Google Drive وسجّل الدخول أولاً.";
"documents.googleDriveImport.tipContinue" = "متابعة";
```

- [ ] **Step 4: Add Romanian strings**

In `Neura/Core/L10n/ro.lproj/Localizable.strings`, find:

```
"documents.photoAccess.message" = "Neura are nevoie de acces la biblioteca ta de poze pentru a încărca imagini. Permite accesul în Setări.";
```

Insert immediately after it:

```
"documents.googleDriveImport.tipTitle" = "Import din Google Drive";
"documents.googleDriveImport.tipMessage" = "În fereastra care se deschide, atinge Browse, apoi Locations, apoi Google Drive. Dacă nu îl vezi, instalează aplicația Google Drive și conectează-te mai întâi.";
"documents.googleDriveImport.tipContinue" = "Continuă";
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

Expected: Same single missing-argument error as Task 1 Step 6 (from `DocsView.swift:31`), and no errors related to `L10n.swift` or the `.strings` files. If `L10n.swift` fails to compile, check for a stray brace mismatch from the inserted enum.

- [ ] **Step 6: Commit**

```bash
git add Neura/Core/L10n/L10n.swift Neura/Core/L10n/en.lproj/Localizable.strings Neura/Core/L10n/ar.lproj/Localizable.strings Neura/Core/L10n/ro.lproj/Localizable.strings
git commit -m "Add L10n strings for Google Drive import tip"
```

---

### Task 3: `DocumentsListViewModel` — `startGoogleDriveImport()` and tip state

**Files:**
- Modify: `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift:58` (add `showDriveImportTip` published property + defaults key)
- Modify: `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift:311-317` (add `startGoogleDriveImport()` and `confirmDriveImportTip()` after `startFileImport()`)

**Interfaces:**
- Consumes: `ensureCanUpload() -> Bool` (existing, `DocumentsListViewModel.swift:323-330`), `showSourcePicker`, `showFileImporter` (existing `@Published` properties).
- Produces: `@Published var showDriveImportTip: Bool`, `func startGoogleDriveImport()`, `func confirmDriveImportTip()`. Task 4 binds `showDriveImportTip` to a new `.alert` and calls both functions.

- [ ] **Step 1: Add the published property and defaults key**

In `Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift`, find (lines 57-58):

```swift
    // File importer
    @Published var showFileImporter = false
```

Replace with:

```swift
    // File importer
    @Published var showFileImporter = false

    // Google Drive import tip
    @Published var showDriveImportTip = false
    private static let hasSeenDriveImportTipKey = "docs.hasSeenDriveImportTip"
```

- [ ] **Step 2: Add `startGoogleDriveImport()` and `confirmDriveImportTip()`**

In the same file, find `startFileImport()` (lines 311-317):

```swift
    func startFileImport() {
        guard ensureCanUpload() else { return }
        showSourcePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFileImporter = true
        }
    }
```

Insert immediately after it (before the `ensureCanUpload()` doc comment on line 319):

```swift

    func startGoogleDriveImport() {
        guard ensureCanUpload() else { return }
        showSourcePicker = false
        if UserDefaults.standard.bool(forKey: Self.hasSeenDriveImportTipKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showFileImporter = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showDriveImportTip = true
            }
        }
    }

    func confirmDriveImportTip() {
        UserDefaults.standard.set(true, forKey: Self.hasSeenDriveImportTipKey)
        showDriveImportTip = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFileImporter = true
        }
    }
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

Expected: Same single missing-argument error at `DocsView.swift:31` as before — no errors inside `DocumentsListViewModel.swift`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Documents/ViewModel/DocumentsListViewModel.swift
git commit -m "Add startGoogleDriveImport and tip state to DocumentsListViewModel"
```

---

### Task 4: Wire `DocsView` — pass `onGoogleDrive`, add the tip alert

**Files:**
- Modify: `Neura/Features/Documents/Views/DocsView.swift:30-39` (pass `onGoogleDrive`, bump sheet height)
- Modify: `Neura/Features/Documents/Views/DocsView.swift:86-95` (add the tip alert after the photo-access alert)

**Interfaces:**
- Consumes: `AddDocumentSheet(onScan:onPhoto:onFile:onGoogleDrive:)` (Task 1), `viewModel.startGoogleDriveImport()`, `viewModel.showDriveImportTip`, `viewModel.confirmDriveImportTip()` (Task 3), `L10n.Documents.GoogleDriveImport.tipTitle/tipMessage/tipContinue` (Task 2).

- [ ] **Step 1: Pass `onGoogleDrive` and bump the sheet height**

In `Neura/Features/Documents/Views/DocsView.swift`, find (lines 30-39):

```swift
        .sheet(isPresented: $viewModel.showSourcePicker) {
            AddDocumentSheet(
                onScan: { viewModel.startScanning() },
                onPhoto: { viewModel.startPhotoUpload() },
                onFile: { viewModel.startFileImport() }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.surfaceWhite)
        }
```

Replace with:

```swift
        .sheet(isPresented: $viewModel.showSourcePicker) {
            AddDocumentSheet(
                onScan: { viewModel.startScanning() },
                onPhoto: { viewModel.startPhotoUpload() },
                onFile: { viewModel.startFileImport() },
                onGoogleDrive: { viewModel.startGoogleDriveImport() }
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.surfaceWhite)
        }
```

(Height goes from 270 to 350 to fit the new 4th row — each row is ~80pt including its divider.)

- [ ] **Step 2: Add the tip alert**

In the same file, find the photo-access alert (lines 86-95):

```swift
        .alert(L10n.Documents.PhotoAccess.title, isPresented: $viewModel.showPhotoPermissionAlert) {
            Button(L10n.Documents.PhotoAccess.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Documents.PhotoAccess.message)
        }
```

Insert immediately after it (before the general error alert on line 96):

```swift
        .alert(L10n.Documents.GoogleDriveImport.tipTitle, isPresented: $viewModel.showDriveImportTip) {
            Button(L10n.Documents.GoogleDriveImport.tipContinue) {
                viewModel.confirmDriveImportTip()
            }
        } message: {
            Text(L10n.Documents.GoogleDriveImport.tipMessage)
        }
```

- [ ] **Step 3: Verify it compiles cleanly**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

Expected: `** BUILD SUCCEEDED **` with no errors or new warnings.

- [ ] **Step 4: Manual verification in the simulator**

1. Run the app in the iPhone 16 simulator.
2. Navigate to the Docs tab, tap the FAB to open the Add Document sheet.
3. Confirm 4 rows appear: Scan Document, Upload from Photos, Import File, Import from Google Drive — with the Drive row showing its full-color logo (not tinted orange like the other three).
4. Tap "Import from Google Drive". Confirm the one-time tip alert appears with the correct title/message/Continue button.
5. Tap Continue. Confirm the system file picker opens.
6. Cancel the picker, reopen the Add Document sheet, tap "Import from Google Drive" again. Confirm the tip alert does **not** appear the second time, and the file picker opens directly.
7. (Optional, requires a physical device with the Google Drive app installed and signed in) Confirm Google Drive appears as a location in the picker and a selected file flows through the metadata form into the documents list like any other imported file.

- [ ] **Step 5: Commit**

```bash
git add Neura/Features/Documents/Views/DocsView.swift
git commit -m "Wire Import from Google Drive into DocsView's add-document flow"
```
