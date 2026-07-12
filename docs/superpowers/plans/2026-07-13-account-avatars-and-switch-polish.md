# Account Avatars & Switch Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the color+initial account chips with real profile photos (pick, crop, edit later), add an "Edit" flow for existing accounts (including the auto-created default one), and polish the switcher row with a brief switch loader and richer visuals.

**Architecture:** New `AccountAvatarStore` (mirrors `CardBackground`'s file-storage pattern — JPEG on disk, filename reference in the synced model). `Space.colorHex` moves from a stored, user-picked field to a computed fallback derived deterministically from `id` (same technique as `CustomFolder.colorSeed`), used only when no avatar is set. `AddSpaceSheet` becomes a shared create/edit sheet with a `PhotosPicker` + new `AvatarCropView`. `SpacesSection`'s chips render the avatar image when present, plus a brief full-screen loader on switch.

**Tech Stack:** SwiftUI, PhotosUI (`PhotosPicker`), UIKit (`UIGraphicsImageRenderer` for the crop render). No new dependencies.

## Global Constraints

- No XCTest target exists (per `CLAUDE.md`). Verification per task = `xcodebuild` build success + a manual check (temporary debug harness in Simulator, removed before commit, following the exact pattern used for the parent Spaces feature — see `docs/superpowers/plans/2026-07-12-family-spaces.md`).
- Avatar photos are **local-only** — not synced to Firestore/Storage (explicit scope decision). Only the `Space.avatarFilename` string reference travels through the existing `SpaceSyncService` blob.
- The crop view (`AvatarCropView`) does not clamp drag offset to keep the image fully covering the circle — a user can theoretically drag far enough to reveal blank space in the cropped result. Accepted simplification for v1; not a silent gap — flagged here explicitly.
- One commit per task, after its build + manual verification pass.
- Reuse `CardBackgroundPickerSheet.swift`'s `PhotosPicker`/`PhotosPickerItem` → `UIImage` pattern exactly; reuse `CustomFolder.colorSeed`'s deterministic-seed-from-UUID-bytes technique for the fallback color.

---

### Task 1: `AccountAvatarStore` + `Space` model changes

**Files:**
- Create: `Neura/Core/Services/AccountAvatarStore.swift`
- Modify: `Neura/Core/Models/Space.swift`

**Interfaces:**
- Produces: `AccountAvatarStore.shared.save(_ image: UIImage, for spaceID: UUID) -> String?`, `.loadImage(filename: String) -> UIImage?`, `.delete(filename: String)`, `.resolveURL(for filename: String) -> URL`. `Space.avatarFilename: String?` (stored). `Space.colorHex: String` (now **computed**, no longer a stored/init parameter).
- Consumes: nothing new.

- [ ] **Step 1: Create `AccountAvatarStore`**

```swift
// Neura/Core/Services/AccountAvatarStore.swift
import Foundation
import UIKit

/// Local-only JPEG storage for account avatar photos, one file per Space id
/// (fixed filename, so re-saving a new photo for the same account overwrites
/// the old one automatically — no orphaned files to clean up). Mirrors
/// CardBackground's custom-photo storage pattern. Not synced to the cloud —
/// only the filename reference travels through SpaceSyncService.
final class AccountAvatarStore {
    static let shared = AccountAvatarStore()

    private let fileManager = FileManager.default

    private var avatarsDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AccountAvatars", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func resolveURL(for filename: String) -> URL {
        avatarsDirectory.appendingPathComponent(filename)
    }

    @discardableResult
    func save(_ image: UIImage, for spaceID: UUID) -> String? {
        let filename = "\(spaceID.uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: resolveURL(for: filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    func loadImage(filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: resolveURL(for: filename)) else { return nil }
        return UIImage(data: data)
    }

    func delete(filename: String) {
        try? fileManager.removeItem(at: resolveURL(for: filename))
    }
}
```

- [ ] **Step 2: Update `Space`** — add `avatarFilename`, make `colorHex` computed

Replace `Neura/Core/Models/Space.swift` in full:

```swift
import Foundation

struct Space: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var isDefault: Bool
    var isArchived: Bool
    /// Filename in AccountAvatarStore, or nil if no photo has been set.
    var avatarFilename: String?

    private static let colorPalette = ["FF5A00", "3498DB", "9B59B6", "27AE60", "E74C3C", "1ABC9C"]

    /// Deterministic fallback color derived from the id — stable across
    /// launches and devices, used only when no avatar photo is set. Not
    /// stored: old persisted data with a "colorHex" JSON key simply has that
    /// key ignored on decode (Codable synthesis no longer looks for it).
    var colorHex: String {
        let b = id.uuid
        let seed = Int(b.0) &+ Int(b.4) &+ Int(b.8) &+ Int(b.12)
        return Self.colorPalette[seed % Self.colorPalette.count]
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        isDefault: Bool = false,
        isArchived: Bool = false,
        avatarFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.isArchived = isArchived
        self.avatarFilename = avatarFilename
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: it will **fail** at this step — `ActiveSpaceManager.makeDefaultSpace()`/`createSpace(name:colorHex:)` and `AddSpaceSheet`/`SpacesSection` still call the old `Space(colorHex:)` initializer and `createSpace(colorHex:)` signature. This is expected; Task 2 fixes `ActiveSpaceManager`, Tasks 4–5 fix the views. Confirm the failure is specifically about the removed `colorHex` init parameter (not something else) before moving on.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Services/AccountAvatarStore.swift Neura/Core/Models/Space.swift
git commit -m "feat: add AccountAvatarStore, make Space.colorHex a deterministic computed fallback"
```

---

### Task 2: `ActiveSpaceManager` — avatar-aware create/update

**Files:**
- Modify: `Neura/Core/Services/ActiveSpaceManager.swift`

**Interfaces:**
- Consumes: `AccountAvatarStore.shared.save` (Task 1).
- Produces: `createSpace(name: String, avatarImage: UIImage?) -> Space` (replaces the old `colorHex`-based signature), new `updateSpace(id: UUID, name: String, avatarImage: UIImage?)`.

- [ ] **Step 1: Add `import UIKit`**

At the top of `Neura/Core/Services/ActiveSpaceManager.swift`:

```swift
import Foundation
import Combine
import UIKit
```

- [ ] **Step 2: Fix `makeDefaultSpace()`**

```swift
    private static func makeDefaultSpace() -> Space {
        Space(id: defaultSpaceID, name: "Me", isDefault: true)
    }
```

- [ ] **Step 3: Replace `createSpace` and add `updateSpace`**

```swift
    @discardableResult
    func createSpace(name: String, avatarImage: UIImage?) -> Space {
        var space = Space(name: name)
        if let avatarImage {
            space.avatarFilename = AccountAvatarStore.shared.save(avatarImage, for: space.id)
        }
        spaces.append(space)
        save()
        return space
    }

    /// Renames an account and optionally replaces its photo (nil = leave the
    /// existing photo, or lack thereof, unchanged).
    func updateSpace(id: UUID, name: String, avatarImage: UIImage?) {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { return }
        spaces[index].name = name
        if let avatarImage {
            spaces[index].avatarFilename = AccountAvatarStore.shared.save(avatarImage, for: id)
        }
        save()
    }
```

- [ ] **Step 4: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: still **fails** — `AddSpaceSheet`/`SpacesSection` (Tasks 4–5) haven't been updated to the new signatures yet. Confirm the failure has moved on from `ActiveSpaceManager.swift` itself (that file now compiles) to the two view files.

- [ ] **Step 5: Commit**

```bash
git add Neura/Core/Services/ActiveSpaceManager.swift
git commit -m "feat: ActiveSpaceManager creates/updates accounts with an avatar image"
```

---

### Task 3: `AvatarCropView`

**Files:**
- Create: `Neura/Features/Profile/Views/Components/AvatarCropView.swift`

**Interfaces:**
- Produces: `AvatarCropView(image: UIImage, onCancel: () -> Void, onConfirm: (UIImage) -> Void)` — a full-screen view; renders a fixed 400×400 circular-cropped `UIImage` on confirm.
- Consumes: nothing new (pure SwiftUI + UIKit rendering).

- [ ] **Step 1: Create the crop view**

```swift
// Neura/Features/Profile/Views/Components/AvatarCropView.swift
import SwiftUI

struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 300
    private let outputSize: CGFloat = 400
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropDiameter, height: cropDiameter)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .gesture(
                            SimultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in lastOffset = offset },
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = min(max(lastScale * value, minScale), maxScale)
                                    }
                                    .onEnded { _ in lastScale = scale }
                            )
                        )
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel, action: onCancel)
                        .tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { onConfirm(renderCroppedImage()) }
                        .tint(.white)
                }
            }
        }
    }

    /// Replicates the on-screen `.scaledToFill()` + gesture scale/offset math
    /// against a fixed-size output, so what the user sees inside the circle
    /// is what gets saved.
    private func renderCroppedImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { _ in
            let clipPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
            clipPath.addClip()

            let ratio = outputSize / cropDiameter
            let imageSize = image.size
            let baseFillScale = max(cropDiameter / imageSize.width, cropDiameter / imageSize.height)
            let drawSize = CGSize(
                width: imageSize.width * baseFillScale * scale * ratio,
                height: imageSize.height * baseFillScale * scale * ratio
            )
            let drawOrigin = CGPoint(
                x: outputSize / 2 - drawSize.width / 2 + offset.width * ratio,
                y: outputSize / 2 - drawSize.height / 2 + offset.height * ratio
            )
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: still fails on `AddSpaceSheet`/`SpacesSection` (unchanged from Task 2's state) — this new file itself must compile cleanly with no new errors attributed to `AvatarCropView.swift`.

- [ ] **Step 3: Commit**

```bash
git add Neura/Features/Profile/Views/Components/AvatarCropView.swift
git commit -m "feat: add AvatarCropView for account photo pick/crop"
```

---

### Task 4: `AddSpaceSheet` becomes a shared create/edit sheet

**Files:**
- Modify: `Neura/Features/Profile/Views/Components/AddSpaceSheet.swift`
- Modify: `Neura/Core/L10n/L10n.swift`
- Modify: `Neura/Core/L10n/en.lproj/Localizable.strings`
- Modify: `Neura/Core/L10n/ar.lproj/Localizable.strings`
- Modify: `Neura/Core/L10n/ro.lproj/Localizable.strings`

**Interfaces:**
- Consumes: `AccountAvatarStore.shared.loadImage` (Task 1), `AvatarCropView` (Task 3).
- Produces: `AddSpaceSheet(mode: .create | .edit(Space), onSave: (String, UIImage?) -> Void)` — `onSave`'s `UIImage?` is `nil` when no new photo was picked (edit mode: existing photo, if any, is left untouched by the caller).

- [ ] **Step 1: Add the L10n key for the edit-mode title**

In `Neura/Core/L10n/L10n.swift`, add to the existing `Profile.Spaces` enum:

```swift
        enum Spaces {
            static var addSpaceTitle: String { "profile.spaces.addSpaceTitle".l10n() }
            static var editSpaceTitle: String { "profile.spaces.editSpaceTitle".l10n() }
            static var namePlaceholder: String { "profile.spaces.namePlaceholder".l10n() }
            static var removeTitle: String { "profile.spaces.removeTitle".l10n() }
            static var removeMessage: String { "profile.spaces.removeMessage".l10n() }
        }
```

Add to `Neura/Core/L10n/en.lproj/Localizable.strings` (next to `profile.spaces.addSpaceTitle`):

```
"profile.spaces.editSpaceTitle" = "Edit Account";
```

Add to `Neura/Core/L10n/ro.lproj/Localizable.strings`:

```
"profile.spaces.editSpaceTitle" = "Editează contul";
```

Add to `Neura/Core/L10n/ar.lproj/Localizable.strings`:

```
"profile.spaces.editSpaceTitle" = "تعديل الحساب";
```

- [ ] **Step 2: Replace `AddSpaceSheet.swift` in full**

```swift
// Neura/Features/Profile/Views/Components/AddSpaceSheet.swift
import SwiftUI
import PhotosUI

struct AddSpaceSheet: View {
    enum Mode {
        case create
        case edit(Space)
    }

    private struct IdentifiableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var avatarImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imagePendingCrop: IdentifiableImage?

    private let mode: Mode
    private let existingColorHex: String?
    let onSave: (String, UIImage?) -> Void

    init(mode: Mode = .create, onSave: @escaping (String, UIImage?) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _avatarImage = State(initialValue: nil)
            existingColorHex = nil
        case .edit(let space):
            _name = State(initialValue: space.name)
            _avatarImage = State(initialValue: space.avatarFilename.flatMap { AccountAvatarStore.shared.loadImage(filename: $0) })
            existingColorHex = space.colorHex
        }
    }

    private var title: String {
        switch mode {
        case .create: return L10n.Profile.Spaces.addSpaceTitle
        case .edit: return L10n.Profile.Spaces.editSpaceTitle
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            avatarPreview
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(L10n.Profile.Spaces.namePlaceholder, text: $name)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, avatarImage)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    imagePendingCrop = IdentifiableImage(image: uiImage)
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(item: $imagePendingCrop) { wrapped in
            AvatarCropView(
                image: wrapped.image,
                onCancel: { imagePendingCrop = nil },
                onConfirm: { cropped in
                    avatarImage = cropped
                    imagePendingCrop = nil
                }
            )
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: existingColorHex ?? "D8D2CB"))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                )
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: still fails, now only on `SpacesSection.swift` (Task 5) — `AddSpaceSheet.swift` and `L10n.swift` themselves must compile cleanly.

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Profile/Views/Components/AddSpaceSheet.swift Neura/Core/L10n/L10n.swift Neura/Core/L10n/en.lproj/Localizable.strings Neura/Core/L10n/ar.lproj/Localizable.strings Neura/Core/L10n/ro.lproj/Localizable.strings
git commit -m "feat: AddSpaceSheet supports photo pick/crop and edit mode"
```

---

### Task 5: `SpacesSection` — avatar rendering, edit wiring, switch loader, visual polish

**Files:**
- Modify: `Neura/Features/Profile/Views/Components/SpacesSection.swift`

**Interfaces:**
- Consumes: `AccountAvatarStore.shared.loadImage` (Task 1), `ActiveSpaceManager.createSpace(name:avatarImage:)` / `.updateSpace(id:name:avatarImage:)` (Task 2), `AddSpaceSheet(mode:onSave:)` (Task 4).

- [ ] **Step 1: Replace `SpacesSection.swift` in full**

```swift
// Neura/Features/Profile/Views/Components/SpacesSection.swift
import SwiftUI

struct SpacesSection: View {
    @StateObject private var activeSpaceManager = ActiveSpaceManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showAddSpace = false
    @State private var showPaywall = false
    @State private var spaceToRemove: Space?
    @State private var editingSpace: Space?
    @State private var isSwitching = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activeSpaceManager.visibleSpaces) { space in
                    SpaceChip(
                        space: space,
                        isActive: space.id == activeSpaceManager.currentSpaceID,
                        onTap: { switchTo(space.id) },
                        onEdit: { editingSpace = space },
                        onRemove: space.isDefault ? nil : { spaceToRemove = space }
                    )
                }

                Button {
                    if subscriptionManager.canCreateSpace {
                        showAddSpace = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 60, height: 60)
                        .background(Color.surfaceWhite)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(Color.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAddSpace) {
            AddSpaceSheet { name, image in
                activeSpaceManager.createSpace(name: name, avatarImage: image)
            }
        }
        .sheet(item: $editingSpace) { space in
            AddSpaceSheet(mode: .edit(space)) { name, image in
                activeSpaceManager.updateSpace(id: space.id, name: name, avatarImage: image)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .fullScreenCover(isPresented: $isSwitching) {
            ZStack {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .tint(Color.accent)
                    .scaleEffect(1.3)
            }
        }
        .alert(
            L10n.Profile.Spaces.removeTitle,
            isPresented: Binding(
                get: { spaceToRemove != nil },
                set: { if !$0 { spaceToRemove = nil } }
            )
        ) {
            Button(L10n.Common.delete, role: .destructive) {
                if let space = spaceToRemove {
                    activeSpaceManager.archiveSpace(id: space.id)
                }
                spaceToRemove = nil
            }
            Button(L10n.Common.cancel, role: .cancel) { spaceToRemove = nil }
        } message: {
            Text(L10n.Profile.Spaces.removeMessage)
        }
    }

    /// Brief (~0.5s) perceived-loading moment before the switch takes effect.
    /// The switch itself is instant (in-memory filter) — this is pure polish.
    private func switchTo(_ spaceID: UUID) {
        guard spaceID != activeSpaceManager.currentSpaceID else { return }
        isSwitching = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            activeSpaceManager.setActive(spaceID)
            isSwitching = false
        }
    }
}

private struct SpaceChip: View {
    let space: Space
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            avatarView
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.backgroundPrimary, lineWidth: isActive ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.accent, lineWidth: isActive ? 2 : 0)
                        .padding(-3)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)

            Text(space.name)
                .font(.captionS)
                .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button(action: onEdit) {
                Label(L10n.Profile.Spaces.editSpaceTitle, systemImage: "pencil")
            }
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label(L10n.Profile.Spaces.removeTitle, systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let filename = space.avatarFilename, let image = AccountAvatarStore.shared.loadImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color(hex: space.colorHex))
                .overlay(
                    Text(space.name.prefix(1).uppercased())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **` — this is the task that closes out every dangling reference from Tasks 1–4.

- [ ] **Step 3: Manual verification**

Launch the app in Simulator, sign in, go to Profile tab. Expected: the default "Me" chip is now 60pt with a soft shadow, and the "+" chip has a dashed border.

Tap "+", the Add Account sheet opens with a camera-icon circle at the top. Tap it, pick a photo from the simulator's photo library (Simulator ships sample photos — if none, add one via `xcrun simctl addmedia booted <path-to-any-png>` first), confirm the crop screen opens full-screen with the photo behind a circular mask; pinch and drag to reposition, tap Done. Expected: back on the Add Account sheet, the circle now shows the cropped photo. Enter a name, tap Save. Expected: a new chip appears in the row with the actual photo (not a color).

Tap the new chip. Expected: a brief dimmed full-screen loader with a spinner appears (~0.5s), then dismisses and the chip shows active.

Long-press (context menu) on the new chip, tap "Edit Account". Expected: the sheet reopens pre-filled with the same name and photo. Change the name only (don't touch the photo), tap Save. Expected: chip's name updates, photo unchanged.

Long-press the default "Me" chip. Expected: the context menu shows only "Edit Account" (no "Remove Account", since it's the default). Tap Edit, confirm it opens pre-filled with "Me" and no photo (or whatever was set), matching current data.

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Profile/Views/Components/SpacesSection.swift
git commit -m "feat: account chips render avatar photos, add edit action and switch loader"
```
