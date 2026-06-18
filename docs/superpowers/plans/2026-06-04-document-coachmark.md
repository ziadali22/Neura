# Document Upload Coachmark — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a one-time arrow-callout coachmark pointing at the FAB after onboarding, dismissing only when the user taps the FAB.

**Architecture:** `DocumentCoachmarkCallout` is a pure visual component (new file). `DashboardView` owns all state and logic — two new properties (`@AppStorage` + `@State`), a `.task` for trigger, and `.onChange(of: coordinator.showAddMenu)` for dismiss. The dim and callout layers sit inside the existing `ZStack`; because `safeAreaInset` renders above the `ZStack`, the FAB naturally punches through the dim with no extra work.

**Tech Stack:** SwiftUI, `@AppStorage` (UserDefaults), `GeometryReader` for safe-area-aware positioning.

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `Neura/Features/Dashboard/Views/Components/DocumentCoachmarkCallout.swift` | White callout card + downward arrow. No logic, no parameters. |
| Modify | `Neura/Features/Dashboard/Views/DashboardView.swift` | Add state, overlay layers, trigger task, dismiss onChange. |

---

## Task 1: Create `DocumentCoachmarkCallout`

**Files:**
- Create: `Neura/Features/Dashboard/Views/Components/DocumentCoachmarkCallout.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct DocumentCoachmarkCallout: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add your first document")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text("Tap + to scan, upload a photo, or import a file.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 210)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            // Arrow pointing down toward the FAB (offset toward trailing)
            CoachmarkArrow()
                .frame(width: 16, height: 9)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 22)
                .offset(y: 8)
        }
    }
}

// MARK: - Arrow shape

private struct CoachmarkArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5).ignoresSafeArea()
        DocumentCoachmarkCallout()
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.bottom, 110)
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 3: Check the preview in Xcode**

Open `DocumentCoachmarkCallout.swift` in Xcode and run the `#Preview`. Confirm:
- White card visible against dark dim
- Title bold, subtitle lighter
- Small downward arrow at the bottom-right of the card

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Dashboard/Views/Components/DocumentCoachmarkCallout.swift
git commit -m "feat: add DocumentCoachmarkCallout view"
```

---

## Task 2: Add coachmark overlay layers to `DashboardView`

**Files:**
- Modify: `Neura/Features/Dashboard/Views/DashboardView.swift`

In this task `showCoachmark` is hardcoded to `true` so the overlay is always visible during development. Task 3 replaces this with real logic.

- [ ] **Step 1: Add state properties**

Inside `DashboardView`, after the existing `@State private var showPaywall = false` line, add:

```swift
@AppStorage("hasSeenDocumentCoachmark") private var hasSeenCoachmark = false
@State private var showCoachmark = true   // hardcoded true for visual testing
```

- [ ] **Step 2: Add the dim and callout layers to the ZStack**

In `DashboardView.body`, inside the `ZStack { ... }`, after the existing `showAddMenu` dim block, add:

```swift
// MARK: Coachmark overlay
if showCoachmark {
    Color.black.opacity(0.45)
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onTapGesture {}          // swallow taps — only the FAB tap dismisses
        .transition(.opacity)

    GeometryReader { geo in
        DocumentCoachmarkCallout()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20)
            .padding(.bottom, geo.safeAreaInsets.bottom + 80)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .transition(
        .opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing))
    )
}
```

The full `ZStack` should now read:

```swift
ZStack {
    // MARK: Tab Content
    switch coordinator.selectedTab {
    case .profile:
        ProfileView()
            .environmentObject(coordinator.profileRouter)
    case .home:
        HomeView()
            .environmentObject(coordinator.homeRouter)
    case .docs:
        DocsView()
    }

    // Existing dim — showAddMenu
    if coordinator.showAddMenu {
        Color.black.opacity(0.35)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    coordinator.showAddMenu = false
                }
            }
            .transition(.opacity)
            .allowsHitTesting(true)
    }

    // MARK: Coachmark overlay
    if showCoachmark {
        Color.black.opacity(0.45)
            .ignoresSafeArea()
            .allowsHitTesting(true)
            .onTapGesture {}
            .transition(.opacity)

        GeometryReader { geo in
            DocumentCoachmarkCallout()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20)
                .padding(.bottom, geo.safeAreaInsets.bottom + 80)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(
            .opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing))
        )
    }
}
```

- [ ] **Step 3: Build and run in simulator**

```bash
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

Launch in the iOS 16 simulator. Confirm:
- Home screen is dimmed
- White callout card is visible above the FAB
- Arrow on the card points toward the FAB
- FAB (orange circle) is clearly visible above the dim
- Tapping the dim does nothing
- Tapping the FAB opens the add menu (coachmark does not yet dismiss — that's Task 3)

- [ ] **Step 4: Commit**

```bash
git add Neura/Features/Dashboard/Views/DashboardView.swift
git commit -m "feat: add coachmark overlay layers to DashboardView"
```

---

## Task 3: Wire trigger and dismiss logic

**Files:**
- Modify: `Neura/Features/Dashboard/Views/DashboardView.swift`

- [ ] **Step 1: Change `showCoachmark` to default `false`**

Replace the hardcoded `true` from Task 2:

```swift
@State private var showCoachmark = false   // real default — trigger task shows it
```

- [ ] **Step 2: Add the trigger `.task`**

Add this modifier to `DashboardView.body`, after the existing `.task(id: scenePhase)`:

```swift
.task {
    guard !hasSeenCoachmark else { return }
    let hasDocs = !DocumentFileManager.shared.loadMetadata()
        .filter { $0.fileExists }
        .isEmpty
    if hasDocs {
        hasSeenCoachmark = true
        return
    }
    try? await Task.sleep(for: .milliseconds(900))
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        showCoachmark = true
    }
}
```

- [ ] **Step 3: Add the dismiss `.onChange`**

Add this modifier directly after the `.task` added in Step 2:

```swift
.onChange(of: coordinator.showAddMenu) { _, open in
    guard open, showCoachmark else { return }
    withAnimation(.easeOut(duration: 0.2)) {
        showCoachmark = false
    }
    hasSeenCoachmark = true
}
```

- [ ] **Step 4: Build**

```bash
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Test the full flow in simulator**

Launch in the iOS 16 simulator. To simulate a fresh user, reset the `hasSeenDocumentCoachmark` flag by running this once in the terminal (resets the simulator app's UserDefaults):

```bash
xcrun simctl spawn booted defaults delete com.Neura.health hasSeenDocumentCoachmark
```

Then cold-launch the app from the simulator home screen.

Verify:
1. Coachmark appears ~900ms after home loads (on first launch with no documents)
2. Dim covers full screen; tapping the dim does nothing
3. FAB is clearly visible above the dim
4. Tapping the FAB: add menu opens AND coachmark fades out simultaneously
5. Kill and relaunch the app — coachmark does NOT appear again
6. Test with existing documents: temporarily call `DocumentFileManager.shared` to confirm the migration path sets `hasSeenCoachmark = true` without showing the coachmark

- [ ] **Step 6: Final commit**

```bash
git add Neura/Features/Dashboard/Views/DashboardView.swift
git commit -m "feat: document upload coachmark — trigger and dismiss logic"
```
