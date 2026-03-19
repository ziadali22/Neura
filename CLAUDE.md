# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native iOS SwiftUI app (no SPM/CocoaPods dependencies). Build and run through Xcode:

```bash
# Open project
open Neura.xcodeproj

# Build from command line
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# No test target exists yet
```

Camera features (document scanning via VisionKit) require a physical device.

## Architecture

**Pattern**: MVVM with SwiftUI. No external dependencies — pure Apple frameworks (SwiftUI, VisionKit, PDFKit, Combine).

**Entry point**: `NeuraApp.swift` → `DashboardView` (TabView with 3 tabs: Profile, Home, Docs).

**Folder structure**:
- `Core/` — Shared design system, extensions, models, services, UI components
- `Features/` — Feature modules following a strict MVVM folder convention

Every feature follows this structure:

```
[FeatureName]/
├── ViewModel/
│   └── [FeatureName]ViewModel.swift
├── Views/
│   ├── [FeatureName]View.swift
│   └── Components/
│       ├── SubComponent1.swift
│       └── SubComponent2.swift
└── Models/
    └── [FeatureName]Model.swift    (if needed)
```

Feature modules:
  - `Dashboard/` — Root tab controller + floating action button
  - `Home/` — Home feed, SecureProfileCard, CompleteProfileCard
  - `HealthProfile/` — Health profile detail (model, view, viewmodel)
  - `Documents/` — Document scanning, listing, categorization, viewers
  - `Profile/` — User settings and Neura Pro

**Navigation**: Each tab that needs drill-down wraps its content in `NavigationStack`. The Home tab uses `navigationDestination(isPresented:)` to push detail views. Sheets are used for modals.

**State flow**: `DashboardView` owns shared state (e.g. `hideFloatingButton`) passed as `@Binding` to child tabs. Feature ViewModels use `@StateObject` in views and `@Published` properties.

## Design System

Use the design tokens defined in `Core/DesignSystem/` — do not use raw hex values:

- **Colors** (`AppColors.swift`): `Color.accent`, `.backgroundPrimary`, `.backgroundCard`, `.backgroundModal`, `.textPrimary`, `.textSecondary`, `.textTertiary`, `.surfaceWhite`, `.surfaceDark`, `.stroke`
- **Typography** (`AppTypography.swift`): `Font.displayArt`, `.headingL`, `.headingS`, `.bodyL`, `.bodyS`, `.buttonL`, `.captionS`, etc. Apply with view modifiers like `.headingSStyle()` for full line-height/tracking control.
- **Hex init**: `Color(hex:)` extension exists in `Color+Hex.swift` but prefer named tokens.

Accent color is orange (#FF5A00). Background is warm off-white (#FCFAF8). Cards use white with 20pt corner radius.

## Conventions

- **File organization**: `// MARK: -` comments to separate sections. Private subviews go in `private extension` blocks.
- **Button style**: Use `ScaleButtonStyle` for interactive cards/buttons.
- **Animations**: Spring animations for view appearances, `withAnimation` for state transitions.
- **Persistence**: `UserDefaults` with JSON encoding for lightweight data (HealthProfile). File system (`DocumentFileManager` singleton) for scanned documents stored under `~/Documents/NeuraScans/`.
- **Concurrency**: `@MainActor` on ViewModels. Main thread for UI, background for file I/O.
- **Xcode file sync**: Project uses filesystem-based file synchronization — new Swift files added to the correct folder are auto-detected without manual Xcode project file editing.

## Pending: QR Code Document Sharing (blocked on Firebase setup)

Feature is fully coded but needs Firebase project setup before it works. QR sharing is Pro-only (free users get PaywallView).

**Flow**: User taps "Share via QR" in document viewer menu → upload to Firebase Storage (REST API) → Cloud Function returns short redirect URL (2h expiry) → QR code generated from short URL → doctor scans → Cloud Function redirects to signed download URL → opens in browser.

**Files already implemented**:
- `Core/Services/FirebaseConfig.swift` — Placeholder config (bucket, Cloud Function URL, API key, 10MB limit, 2h expiry). Replace `YOUR_*` values after setup.
- `Core/Extensions/UIImage+QRCode.swift` — Shared `UIImage.qrCode(from:size:)` utility via CoreImage.
- `Core/Services/CloudUploadService.swift` — `CloudUploadService` protocol + `FirebaseUploadService`. Two-step REST: POST file to Storage, then call Cloud Function for short URL. Returns `ExpiringLink(url, expiresAt)`.
- `Features/Documents/ViewModel/ShareDocumentViewModel.swift` — State machine (`idle → uploading → ready → expired`, plus `error`). Countdown timer, copy-to-clipboard, link regeneration.
- `Features/Documents/Views/Components/ShareDocumentSheet.swift` — Sheet UI with 4 states: uploading, QR code + countdown, expired + regenerate, error + retry.
- `Features/Documents/Views/Components/DocumentViewerView.swift` — "Share via QR" option in three-dot menu, Pro-gated.
- `Features/Home/Views/Components/ShareHealthProfileSheet.swift` — Share button generates PDF via `HealthProfileViewModel.generatePDF()`, uploads, shows QR.
- `Core/Services/SubscriptionManager.swift` — `shareCount`, `canShareViaQR`, `recordShare()` for free-tier tracking (1 free share).

**Firebase setup needed**:
1. Create Firebase project at console.firebase.google.com
2. Enable Firebase Storage
3. Deploy Cloud Function (POST `/getShareUrl` + GET `/share/{fileId}` redirect with 2h signed URL)
4. Set lifecycle rule on `shared/` prefix (24h auto-delete)
5. Copy config values into `FirebaseConfig.swift`
