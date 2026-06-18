# Document Upload Coachmark — Design Spec

**Date:** 2026-06-04
**Branch:** feature/new-onboarding

---

## Overview

After a user completes onboarding and lands on HomeView for the first time, show a one-time coachmark that points at the FAB (the orange "+" button) and instructs them to upload their first document. The coachmark dismisses only when the user taps the FAB.

---

## Visual Design

- **Style:** Arrow callout with full-screen dim backdrop
- **Dim:** `Color.black.opacity(0.45)` covering the entire screen including safe area. The FAB punches through naturally because it lives in `safeAreaInset`, which renders above the `ZStack`.
- **Callout bubble:** White rounded card (corner radius 14pt), positioned bottom-trailing above the FAB. Contains:
  - Title: "Add your first document" (semibold, 15pt, textPrimary)
  - Subtitle: "Tap + to scan, upload a photo, or import a file." (13pt, textSecondary)
  - Downward-pointing triangle arrow aligned with the FAB center
- **Positioning:** `GeometryReader` measures `safeAreaInsets.bottom` at runtime; callout bottom = `safeAreaInsets.bottom + 80pt` (clears the FAB top with an 8pt gap)

---

## State & Trigger Logic

### Properties added to `DashboardView`

```swift
@AppStorage("hasSeenDocumentCoachmark") private var hasSeenCoachmark = false
@State private var showCoachmark = false
```

`AppStorage` persists across launches. `showCoachmark` drives the animated entry/exit within the session.

### Trigger (`.task` on `DashboardView`)

1. If `hasSeenCoachmark == true` → return immediately (returning user, no coachmark)
2. If user already has documents (`DocumentFileManager.shared.loadMetadata().filter { $0.fileExists }` is non-empty) → set `hasSeenCoachmark = true` silently and return (migration path for users who had documents before this feature shipped)
3. Otherwise → `Task.sleep(for: .milliseconds(900))` to let home entrance animations settle, then animate `showCoachmark = true` with `.spring(response: 0.4, dampingFraction: 0.8)`

### Dismiss (`.onChange(of: coordinator.showAddMenu)`)

When `showAddMenu` flips to `true` (user tapped the FAB):
- Animate `showCoachmark = false` with `.easeOut(duration: 0.2)`
- Set `hasSeenCoachmark = true` to prevent future appearances

---

## Files

### Modified
- `Neura/Features/Dashboard/Views/DashboardView.swift` — add `hasSeenCoachmark`, `showCoachmark`, dim layer, trigger task, and dismiss onChange

### New
- `Neura/Features/Dashboard/Views/Components/DocumentCoachmarkCallout.swift` — purely visual callout bubble (white card + arrow). No logic. Takes no parameters.

---

## Implementation Notes

- The dim layer uses `.allowsHitTesting(true)` with an empty `onTapGesture {}` to swallow taps — the only way to dismiss is via the FAB
- Entry transition: `.opacity` + `.scale(scale: 0.9, anchor: .bottomTrailing)` spring
- Exit transition: `.opacity` `.easeOut(duration: 0.2)`
- No new dependencies — pure SwiftUI

---

## Out of Scope

- Multiple coachmarks / coachmark sequencing
- Coachmark for any other action besides document upload
- Analytics events (can be added later via the Mixpanel skill)
