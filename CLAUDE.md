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
- `Features/` — Feature modules, each with its own View, ViewModel, and Components subfolder
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
