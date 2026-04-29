# SwiftUI Onboarding — How It Was Built

A screen-by-screen breakdown of the Neura onboarding flow. Everything here is taken
directly from the code you have in front of you. Study this alongside the actual files.

---

## Table of Contents

1. [How SwiftUI Thinks](#1-how-swiftui-thinks)
2. [The MVVM Pattern](#2-the-mvvm-pattern)
3. [Property Wrappers — The Core of SwiftUI State](#3-property-wrappers)
4. [Architecture Decision: The State Machine](#4-the-state-machine)
5. [The ViewModel — Brain of the Flow](#5-the-viewmodel)
6. [The Container View — OnboardingView](#6-the-container-view)
7. [Transitions Between Screens](#7-transitions-between-screens)
8. [Screen by Screen Breakdown](#8-screen-by-screen-breakdown)
9. [Animation Patterns Used](#9-animation-patterns)
10. [The Design System](#10-the-design-system)
11. [Persisting Data](#11-persisting-data)
12. [Best Practices Cheatsheet](#12-best-practices-cheatsheet)

---

## 1. How SwiftUI Thinks

SwiftUI is **declarative**. You describe *what* the UI should look like for a given state,
and SwiftUI figures out *how* to render it. This is the opposite of UIKit, where you
imperatively tell the system *how* to change things.

```swift
// UIKit (imperative) — you manually update the label
label.text = "Hello"
label.isHidden = false

// SwiftUI (declarative) — you describe the state
if showGreeting {
    Text("Hello")
}
```

The key insight: **whenever state changes, SwiftUI re-runs `body` and diffs the result.**
You never manually update views — you update state and let SwiftUI redraw.

### The View Protocol

Every screen in SwiftUI is a `struct` that conforms to `View`. The only requirement is a
computed property called `body` that returns `some View`.

```swift
struct MyView: View {
    var body: some View {
        Text("Hello")
    }
}
```

`some View` is an **opaque return type** — it means "some specific type that conforms to
View, but I won't tell you exactly which type." This lets you return complex view trees
without spelling out the full nested generic type.

### Structs, Not Classes

Views are `struct`s (value types), not classes. This matters because:
- Structs are copied, not referenced — no accidental shared mutation
- SwiftUI creates them cheaply and throws them away after each render pass
- State lives *outside* the struct body, managed by SwiftUI's property wrapper system

---

## 2. The MVVM Pattern

Neura uses **Model-View-ViewModel (MVVM)**. Every feature folder follows this layout:

```
Onboarding/
├── Models/
│   └── OnboardingModels.swift     ← Data structures, enums
├── ViewModel/
│   └── OnboardingViewModel.swift  ← Business logic, state, actions
└── Views/
    ├── OnboardingView.swift        ← Container / coordinator
    └── Steps/
        ├── OnboardingWelcomeStep.swift
        ├── OnboardingProfileStep.swift
        └── ...
```

**What each layer does:**

| Layer | Responsibility | SwiftUI type |
|---|---|---|
| **Model** | Pure data. No UI. No logic. | `struct`, `enum` |
| **ViewModel** | Holds state, runs logic, talks to services | `@MainActor class` + `ObservableObject` |
| **View** | Renders state, sends events to ViewModel | `struct View` |

**The rule:** Views never own business logic. They observe the ViewModel and call its
methods. The ViewModel never imports SwiftUI (ideally) and never directly manipulates views.

---

## 3. Property Wrappers

Property wrappers are the most important concept in SwiftUI. They are special attributes
you put in front of a property that give it superpowers.

### `@State` — Local View State

```swift
@State private var appeared = false
```

- Lives inside one view and belongs to that view alone
- When it changes, SwiftUI re-renders that view
- Always `private` — no other view should touch it
- Persists across re-renders of the same view instance

**Use it for:** UI toggles, animation flags, local selection state

```swift
// OnboardingProfileStep.swift
@State private var appeared = false
@State private var showDatePicker = false
@FocusState private var nameFocused: Bool   // special @State for keyboard focus
```

### `@Published` — ViewModel State That Views Watch

```swift
@Published var currentStep: OnboardingStep = .welcome
@Published var state = OnboardingState()
```

- Lives in an `ObservableObject` class (the ViewModel)
- When it changes, SwiftUI automatically re-renders any view observing it
- The `$` prefix gives you a `Publisher` you can subscribe to with Combine

**Think of it as:** the ViewModel's way of saying "watch this value."

### `@ObservedObject` — Connect a View to a ViewModel

```swift
@ObservedObject var viewModel: OnboardingViewModel
```

- Tells the view to re-render whenever any `@Published` property on `viewModel` changes
- The view does NOT own the object — it was created elsewhere and passed in
- Used in every single step view in this project

```swift
// Every step receives the same ViewModel instance:
struct OnboardingProfileStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
```

### `@StateObject` — Own and Create a ViewModel

```swift
@StateObject private var viewModel = OnboardingViewModel()
```

- Like `@ObservedObject` but the view *owns* and *creates* the object
- SwiftUI keeps it alive for the view's entire lifetime — it won't be recreated on re-renders
- Used only in `OnboardingView` (the container), because that's where the ViewModel is born

```swift
// OnboardingView.swift — creates and owns the ViewModel
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
```

### `@Binding` — Two-Way Connection Between Views

```swift
@Binding var isPresented: Bool
```

- A reference to state that lives in a parent view
- Reading it reads the parent's state; writing it updates the parent's state
- Created by putting `$` in front of the state: `SplashView(isPresented: $showSplash)`

```swift
// SplashView.swift — the parent passes its $showSplash
struct SplashView: View {
    @Binding var isPresented: Bool  // controls when this view disappears

    // When animation finishes:
    isPresented = false  // this sets showSplash = false in NeuraApp
```

### Quick Reference

| Wrapper | Where | Who owns it | When to use |
|---|---|---|---|
| `@State` | View | That view | Local UI state (toggles, animations) |
| `@Published` | ViewModel | ViewModel | Data views should react to |
| `@ObservedObject` | View | Someone else | Receive a ViewModel |
| `@StateObject` | View | That view | Create and own a ViewModel |
| `@Binding` | View | Parent view | Two-way link to parent's state |
| `@Environment` | View | SwiftUI system | System values (colorScheme, locale) |

---

## 4. The State Machine

The onboarding is a **state machine** — the app is always in exactly one state (step),
and explicit rules define which states you can move to.

### The Step Enum

```swift
// OnboardingModels.swift
enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case storeAndShare
    case documentScan
    case privacySecurity
    case medicalAreas
    case profile, location, profileCard
    case emergency, biometrics, emergencyCard
    case healthKit, healthData, medical, documents
}
```

**Why an enum?**
- The compiler enforces that every case is handled — you can't forget a screen
- `switch` on an enum produces a warning if you add a new case but forget to handle it
- It's self-documenting: the whole flow is visible in one place
- `Hashable` conformance lets it be used as a dictionary key or `id` in `ForEach`

**Why `Int, CaseIterable`?**
- `Int` raw value lets you compare steps by position if needed
- `CaseIterable` gives you `OnboardingStep.allCases` — all steps as an array

### Computed Properties on the Enum

The enum also carries UI logic about itself:

```swift
/// Whether the top bar (back button + progress) is visible.
var showsTopBar: Bool { self != .welcome }

/// Whether the centered progress pill is shown within the top bar.
var showsProgressBar: Bool {
    switch self {
    case .welcome, .storeAndShare, .documentScan, .privacySecurity: return false
    default: return true
    }
}
```

This is the **"push logic to the model" principle** — instead of writing `if step == .welcome`
scattered across views, you ask the step itself what it needs.

### Progress Tracking

```swift
static let progressTracked: [OnboardingStep] = [
    .medicalAreas, .profile, .location, .profileCard, .emergency,
    .biometrics, .emergencyCard, .healthKit, .medical, .documents
]
```

Not all steps contribute to the progress bar (the intro steps don't). This array defines
exactly which steps count. The ViewModel computes progress from it:

```swift
var progress: Double {
    let tracked = OnboardingStep.progressTracked
    let step = currentStep == .healthData ? .healthKit : currentStep
    guard let idx = tracked.firstIndex(of: step) else { return 0 }
    return Double(idx + 1) / Double(tracked.count)
}
```

---

## 5. The ViewModel

`OnboardingViewModel` is the single source of truth for the entire onboarding flow.

```swift
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var state = OnboardingState()
    @Published var direction: Int = 1    // +1 = forward, -1 = backward (for transitions)
    @Published var isComplete = false
```

### `@MainActor`

This attribute ensures every method and property access on this class happens on the
main thread. UI updates must be on the main thread — `@MainActor` makes that automatic.
Without it, you'd have to write `DispatchQueue.main.async { }` everywhere.

### `final class`

- `class` (not `struct`) because `ObservableObject` requires a reference type
- `final` means nothing can subclass it — enables compiler optimizations

### `ObservableObject`

This protocol makes the class observable by SwiftUI. When any `@Published` property
changes, SwiftUI views that hold an `@ObservedObject` or `@StateObject` reference to
this class will re-render automatically.

### The Navigation Methods

```swift
func advance() {
    direction = 1
    let next = nextStep(after: currentStep)
    if next == currentStep {
        finalize()          // last step — we're done
    } else {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep = next
        }
    }
}

func goBack() {
    direction = -1
    let prev = previousStep(before: currentStep)
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
        currentStep = prev
    }
}
```

`direction` is set BEFORE changing `currentStep`. By the time the transition runs,
`direction` is already `-1` or `+1`, so the transition knows which way to slide.

### The Navigation Switch

```swift
private func nextStep(after step: OnboardingStep) -> OnboardingStep {
    switch step {
    case .welcome:         return .storeAndShare
    case .storeAndShare:   return .documentScan
    // ...
    case .healthKit:
        // Conditional branching — only goes to .healthData if HealthKit was authorized
        if healthKitStatus == .authorized, healthKitData?.hasAnyData == true {
            return .healthData
        }
        return .medical
    // ...
    }
}
```

**Key insight:** the navigation logic is centralized here, not scattered across views.
Steps don't know what comes next — the ViewModel decides. This makes it trivial to
add, remove, or reorder steps without touching individual screen files.

### The `OnboardingState` Struct

```swift
struct OnboardingState {
    var name: String = ""
    var dateOfBirth: Date? = nil
    var gender: ProfileGender? = nil
    var bloodType: BloodType? = nil
    var emergencyContactName: String = ""
    var emergencyContactPhone: String = ""
    var city: String = ""
    var country: String = ""
    var medications: String = ""
    var allergies: String = ""
    var conditions: String = ""
    var cardBackground: CardBackground = .default
}
```

This `struct` holds every piece of data collected across all onboarding screens. It's
a **value type** — when you assign it or pass it around, it's copied. The ViewModel owns
one instance: `@Published var state = OnboardingState()`.

When any view writes `viewModel.state.name = "Ziad"`, the whole `state` struct is replaced
with a new copy (value semantics), which triggers `@Published` to fire, which re-renders
any view watching that ViewModel.

---

## 6. The Container View

`OnboardingView` is a **container** — it doesn't display content itself. It manages the
top bar, transitions, and delegates content rendering to individual step views.

```swift
struct OnboardingView: View {
    let onComplete: () -> Void          // callback to the parent (NeuraApp)
    @StateObject private var viewModel = OnboardingViewModel()
```

`onComplete` is a plain Swift closure passed from `NeuraApp`. When onboarding finishes,
the ViewModel sets `isComplete = true`, the container detects that, and calls `onComplete()`.

```swift
.onChange(of: viewModel.isComplete) { _, done in
    if done { onComplete() }
}
```

### The Top Bar

```swift
private var topBar: some View {
    ZStack {
        // Center: progress pill (only when relevant)
        if viewModel.currentStep.showsProgressBar {
            progressBar
        }
        // Left: back button
        HStack {
            if viewModel.currentStep != .welcome {
                Button("Back", systemImage: "chevron.left") {
                    viewModel.goBack()
                }
                .labelStyle(.iconOnly)
                // ...
            }
            Spacer()
        }
    }
}
```

Notice the top bar's height is animated:

```swift
.frame(height: viewModel.currentStep.showsTopBar ? 44 : 0)
.clipped()
```

When `showsTopBar` is false (welcome step), the frame animates to height 0 and `.clipped()`
hides any overflow. This avoids a jarring pop — the top bar slides away smoothly.

### The `@ViewBuilder` Switch

```swift
@ViewBuilder
private var stepContent: some View {
    Group {
        switch viewModel.currentStep {
        case .welcome:         OnboardingWelcomeStep(viewModel: viewModel)
        case .profile:         OnboardingProfileStep(viewModel: viewModel)
        case .profileCard:     OnboardingProfileCardStep(viewModel: viewModel)
        // ...
        }
    }
    .id(viewModel.currentStep)           // forces SwiftUI to treat each step as NEW
    .transition(stepTransition)
    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.currentStep)
}
```

**The `.id()` modifier is critical.** Without it, SwiftUI sees two consecutive
`OnboardingProfileStep` instances and tries to animate *within* the existing view.
With `.id(viewModel.currentStep)`, each new step is treated as a completely new view,
and the `transition` fires between them.

**`@ViewBuilder`** is what allows you to use `if`, `switch`, and `ForEach` directly
inside a computed property that returns a view. Without it, you'd get a compile error.

---

## 7. Transitions Between Screens

```swift
private var stepTransition: AnyTransition {
    .asymmetric(
        insertion: .move(edge: viewModel.direction > 0 ? .trailing : .leading)
                    .combined(with: .opacity),
        removal:   .move(edge: viewModel.direction > 0 ? .leading  : .trailing)
                    .combined(with: .opacity)
    )
}
```

An **asymmetric transition** has different animations for appearing and disappearing.

- Going **forward** (`direction = 1`):
  - New step slides in from the **trailing** (right) edge
  - Old step slides out to the **leading** (left) edge
- Going **backward** (`direction = -1`):
  - New step slides in from the **leading** (left) edge
  - Old step slides out to the **trailing** (right) edge

Combined with `.opacity` prevents a hard edge at the screen boundary — steps fade
slightly as they move, which feels much more natural.

`.combined(with:)` merges two transitions, running them simultaneously.

---

## 8. Screen by Screen Breakdown

### Pattern All Steps Share

Every step follows this exact structure:

```swift
struct OnboardingXxxStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    // 1. Local animation flags
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // 2. Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header (title + subtitle)
                    // Main content
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)      // 3. Entrance animation
                .offset(y: appeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)

            // 4. Continue button pinned at the bottom
            continueButton
        }
        // 5. Trigger entrance animation after a short delay
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}
```

**Why `.task` instead of `.onAppear`?**
`.task` runs an `async` closure and automatically cancels it if the view disappears.
`.onAppear` is synchronous. Async/await (`Task.sleep`) is far cleaner than
`DispatchQueue.main.asyncAfter`.

**Why the 100ms delay?**
The step transition animation takes ~200ms. If the entrance animation started instantly,
it would compete with the transition and look messy. The 100ms delay lets the step
finish sliding into place before its content fades in.

---

### Welcome Step — `OnboardingWelcomeStep`

The first impression. No top bar, gradient background (handled by `OnboardingView`).

**Key technique — staggered entrance animation:**
Instead of one `appeared` flag for everything, the welcome step likely has multiple
flags so the logo, title, subtitle, and button each animate in sequentially with delays.

**Lesson:** Staggered animations feel polished because the eye can follow each element
arriving rather than being hit by everything at once.

---

### Profile Step — `OnboardingProfileStep`

Collects name, date of birth, and gender.

```swift
// Two-way data binding: TextField writes directly into the ViewModel's state
TextField("Your full name", text: $viewModel.state.name)
```

The `$` prefix turns `viewModel.state.name` into a `Binding<String>`. The text field
reads the current value and writes back to it whenever the user types.

**The Date Picker fix:**

```swift
DatePicker("", selection: $localDate, in: ...Date(), displayedComponents: .date)
    .datePickerStyle(.graphical)
```

`localDate` is `@State` local to this view. The picker writes to `localDate`, and
an `.onChange` syncs it to `viewModel.state.dateOfBirth`.

The bug that was fixed: `ScrollView` had `.onTapGesture { nameFocused = false }`
which consumed all taps — including the day cells in the graphical date picker.
Fixed by using `.scrollDismissesKeyboard(.immediately)` instead, which lets taps
pass through to child views.

**`in: ...Date()`** is a `PartialRangeThrough` — it limits the picker to dates on or
before today. The `...` before `Date()` means "any date up to and including this date."

**`@FocusState`** is a special property wrapper that lets you programmatically control
which text field has keyboard focus:

```swift
@FocusState private var nameFocused: Bool
TextField("...", text: $viewModel.state.name)
    .focused($nameFocused)
```

Setting `nameFocused = false` dismisses the keyboard.

---

### Profile Card Step — `OnboardingProfileCardStep`

The horizontal card carousel. This is the most technically interesting step.

```swift
@State private var scrolledID: String? = CardBackground.gradientBackgrounds.first?.id
private let presets = CardBackground.gradientBackgrounds

private var selectedIndex: Int {
    guard let id = scrolledID else { return 0 }
    return presets.firstIndex(where: { $0.id == id }) ?? 0
}
```

**`scrollPosition(id:)`** — iOS 17 API. Binds to the ID of the currently centered item.
As the user scrolls, `scrolledID` updates automatically.

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 16) {
        ForEach(presets) { bg in
            SecureProfileCard(name: displayName, location: displayLocation, background: bg)
                .allowsHitTesting(false)            // prevent card's DragGesture fighting ScrollView
                .containerRelativeFrame(.horizontal) { width, _ in width - 80 }
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.88)
                        .opacity(phase.isIdentity ? 1 : 0.65)
                }
                .id(bg.id)
        }
    }
    .scrollTargetLayout()
    .padding(.horizontal, 40)
}
.scrollTargetBehavior(.viewAligned)
.scrollIndicators(.hidden)
.scrollPosition(id: $scrolledID)
```

**`containerRelativeFrame`** — the modern way to size something relative to its container.
`width - 80` means each card is 80pt narrower than the screen. With `.padding(.horizontal, 40)`
on the HStack, the first card's center aligns perfectly with the screen center.

**Math:** screen = 390pt. Card = 310pt. Each side: (390 - 310) / 2 = 40pt. So neighboring
cards peek in by exactly 40pt - 16pt spacing = 24pt. Visible but clearly peeking.

**`scrollTargetBehavior(.viewAligned)`** — snaps so each item centers in the scroll view.
Requires `.scrollTargetLayout()` on the inner stack to know which items to snap to.

**`scrollTransition`** — animates views as they enter/leave the scroll view's visible area.
`phase.isIdentity` is true only for the centered card. Off-center cards are 88% scale
and 65% opacity — creating the "carousel depth" effect without any manual math.

**`.allowsHitTesting(false)`** — `SecureProfileCard` has its own `DragGesture` for 3D
tilt. In a horizontal `ScrollView`, that gesture would fight with scroll gestures. Disabling
hit testing makes the cards purely visual inside the scroll view.

**Staggered entrance animation:**
```swift
@State private var headerAppeared = false
@State private var carouselAppeared = false
@State private var buttonAppeared = false

.task {
    try? await Task.sleep(for: .milliseconds(100))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { headerAppeared = true }
    try? await Task.sleep(for: .milliseconds(250))
    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { carouselAppeared = true }
    try? await Task.sleep(for: .milliseconds(200))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { buttonAppeared = true }
}
```

Three separate flags, each triggering its own animation section in sequence.
The carousel gets a slightly slower spring (`response: 0.6`) to give it more weight.

---

### Emergency Step — `OnboardingEmergencyStep`

Standard form step. Demonstrates `TextField` with contact data:

```swift
TextField("Contact name", text: $viewModel.state.emergencyContactName)
TextField("Phone number", text: $viewModel.state.emergencyContactPhone)
    .keyboardType(.phonePad)
```

`.keyboardType(.phonePad)` shows the numeric phone keyboard — a small detail that
matters a lot for UX. Always use the right keyboard for the data type.

---

### HealthKit Step — `OnboardingHealthKitStep`

Demonstrates async permission requests:

```swift
Button("Connect Health") {
    viewModel.requestHealthKit()
}
```

```swift
// In ViewModel:
func requestHealthKit() {
    Task {
        healthKitStatus = .requesting
        let result = await healthKitService.requestAuthorization()
        // ... handle result
        advance()
    }
}
```

`Task { }` creates an unstructured concurrency task — it runs concurrently without
blocking the calling thread. Since `OnboardingViewModel` is `@MainActor`, the `Task`
inherits the main actor context, so `healthKitStatus = .requesting` is safe.

The view observes `healthKitStatus` (a `@Published` enum) and shows different UI for
`.notRequested`, `.requesting`, `.authorized`, `.denied`.

---

### Emergency Card Step — `OnboardingCardStep`

The preview of the emergency card. Teaches **multi-phase entrance animation**:

```swift
@State private var cardAppear = false
@State private var actionsAppear = false

.task {
    try? await Task.sleep(for: .milliseconds(200))
    withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { cardAppear = true }
    try? await Task.sleep(for: .milliseconds(400))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { actionsAppear = true }
}
```

The card animates in first (response: 0.7 — slow and weighty), then the continue button
(response: 0.5 — snappier). This creates a reading order: look at the card, then notice
the button. Good UX.

`response` in a spring animation is roughly how long it takes to settle (in seconds).
`dampingFraction` controls bounciness: 1.0 = no bounce, 0.5 = quite bouncy.

---

## 9. Animation Patterns

### Pattern 1 — Simple Entrance (Most Steps)

```swift
@State private var appeared = false

.opacity(appeared ? 1 : 0)
.offset(y: appeared ? 0 : 16)

.task {
    try? await Task.sleep(for: .milliseconds(100))
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
        appeared = true
    }
}
```

Animates opacity from 0→1 and offset from +16pt→0 simultaneously. The offset creates
the illusion of content "rising into place." 16pt is subtle — not a huge slide.

### Pattern 2 — Staggered Cards (GoalsStep)

```swift
ForEach(Array(UserGoal.allCases.enumerated()), id: \.element.id) { index, goal in
    GoalCard(...)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.85)
                .delay(Double(index) * 0.09),
            value: appeared
        )
}

.task {
    try? await Task.sleep(for: .milliseconds(100))
    appeared = true    // no withAnimation — the per-view .animation modifier handles it
}
```

Each card gets a `.animation(_:value:)` modifier with an increasing `.delay()`.
Setting `appeared = true` without `withAnimation` is intentional here — the individual
modifiers handle their own animation when they detect `appeared` change.

**Why not `withAnimation` here?** If you used `withAnimation(.spring()) { appeared = true }`,
all cards would share the same global animation context — the delays would be ignored.
By relying on per-view `.animation(_:value:)`, each card animates independently.

### Pattern 3 — Selection Toggle (GoalsStep cards)

```swift
withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
    if viewModel.state.goals.contains(goal) {
        viewModel.state.goals.remove(goal)
    } else {
        viewModel.state.goals.insert(goal)
    }
}
```

The `withAnimation` block wraps the state change, not a view modifier. SwiftUI sees
the state change, re-renders the view, and animates the diff using the provided spring.

### Pattern 4 — Scale Press Effect (ScaleButtonStyle)

```swift
.buttonStyle(ScaleButtonStyle())
```

A custom `ButtonStyle` that scales the button to 0.96 on press. Defined once in the
design system, applied everywhere. This is the "feels native" touch feedback pattern.

### Spring Physics Quick Reference

```
response:       how long the spring takes to settle (seconds)
                0.3 = snappy     0.5 = normal     0.8 = slow/weighty

dampingFraction: how much it bounces
                1.0 = no bounce  0.85 = subtle    0.6 = noticeable bounce
```

---

## 10. The Design System

```swift
// AppColors.swift
extension Color {
    static let accent           = Color(hex: "FF5A00")  // orange
    static let backgroundPrimary = Color(hex: "FCFAF8") // warm off-white
    static let textPrimary      = Color(hex: "1F1F1F")
    static let textSecondary    = Color(hex: "4A4A4A")
    static let surfaceWhite     = Color(hex: "FFFFFF")
    static let stroke           = Color(hex: "E7E0D8")
}
```

**Why a design system?**
1. **Consistency** — every screen uses the same exact orange, not slightly different ones
2. **Refactoring** — to change the brand color, edit one line; not 200 places
3. **Readability** — `.accent` is self-documenting; `Color(hex: "FF5A00")` is not
4. **Prevents raw hex values** — the CLAUDE.md rule says "do not use raw hex values"

**Typography tokens** follow the same principle:
```swift
// Used as: Text("Hello").font(.displayL)
// or:      Text("Hello").headingSStyle()   ← applies font + line-height + tracking
```

**The `Color(hex:)` extension** in `Color+Hex.swift` lets you initialize colors from hex
strings. It exists to bridge between Figma (where designers specify hex codes) and SwiftUI.

---

## 11. Persisting Data

At the end of onboarding, `saveProfile()` in the ViewModel writes everything to storage.

### UserDefaults

```swift
// Simple value
UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

// Complex object — encode to JSON first
if let data = try? JSONEncoder().encode(profile) {
    UserDefaults.standard.set(data, forKey: "health_profile_data")
}

// Reading back
if let data = UserDefaults.standard.data(forKey: "health_profile_data"),
   let profile = try? JSONDecoder().decode(HealthProfile.self, from: data) {
    // use profile
}
```

`UserDefaults` stores key-value pairs persistently on disk. It supports primitives
(Bool, Int, String, Data) directly. For custom types, encode them to `Data` using
`JSONEncoder` first.

**The `Codable` protocol** (combining `Encodable` + `Decodable`) gives any struct
automatic JSON encoding/decoding via the compiler if all its properties are also Codable.

### The Card Background Persistence

```swift
// CardBackgroundPickerSheet.swift
func save() {
    if let data = try? JSONEncoder().encode(self) {
        UserDefaults.standard.set(data, forKey: "selected_card_background")
    }
}

static func saved() -> CardBackground {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let bg = try? JSONDecoder().decode(CardBackground.self, from: data) else {
        return .default
    }
    return bg
}
```

`CardBackground` conforms to `Codable`, so it encodes itself to JSON automatically.
`HomeView` loads the saved background on appear: `@State private var cardBackground: CardBackground = CardBackground.saved()`

---

## 12. Best Practices Cheatsheet

### Architecture
- **One ViewModel per feature.** Don't share ViewModels between unrelated features.
- **ViewModels are `@MainActor final class`.** `@MainActor` for thread safety. `final` for performance.
- **Views are thin.** They render state and forward taps/events. Zero logic.
- **State lives in one place.** `OnboardingState` struct holds ALL collected data.
  Views read from it via `viewModel.state.xxx` and write via `$viewModel.state.xxx`.

### SwiftUI
- **Never call `body` directly.** SwiftUI calls it for you.
- **`.id()` forces view replacement.** Use when you need transitions between same-type views.
- **`@StateObject` only at the creation site.** Every other view gets `@ObservedObject`.
- **`@Binding` for two-way child-to-parent communication.** Not for everything.
- **Avoid `GeometryReader` when possible.** Prefer `containerRelativeFrame`, `visualEffect`.
- **Use `.task {}` not `.onAppear {}` for async work.** Task cancels automatically.

### Animations
- **Wrap state changes in `withAnimation`, not view modifiers.** `withAnimation { state = newValue }`
  animates the effect of the state change on ALL affected views.
- **Or use `.animation(_:value:)` for per-view control.** Fires when the `value` changes.
- **Never use `.animation()` without a `value:`.** The old form animates everything, always.
- **For sequences, use `Task.sleep` between `withAnimation` calls** in an async function.
- **Respect Reduce Motion.** Read `@Environment(\.accessibilityReduceMotion)` and skip
  scale/translate animations, keeping only fades.

### Design
- **Never hardcode hex colors in views.** Use design tokens.
- **Never use `foregroundColor()`.** Use `foregroundStyle()` (supports gradients, vibrancy).
- **Use `clipShape(.rect(cornerRadius:))` not `.cornerRadius()`.** Modern API.
- **`scrollDismissesKeyboard(.immediately)`** instead of `.onTapGesture` on ScrollView.
  The gesture was intercepting child view taps (the date picker bug).

### Accessibility
- **Decorative images get `.accessibilityHidden(true)`.** The logo in SplashView, icons
  inside labeled buttons — these add noise to VoiceOver.
- **Icon-only buttons must have a text label.** `Button("Back", systemImage: "chevron.left")`
  with `.labelStyle(.iconOnly)` shows only the icon visually but reads "Back" to VoiceOver.
- **`.keyboardType(.phonePad)`** for phone numbers, `.emailAddress` for email, etc.
- **`.submitLabel(.done)`** on the last TextField in a form shows "Done" on the keyboard.

---

## How to Read the Code

Start with these files in order:

1. `OnboardingModels.swift` — understand the data and the step enum
2. `OnboardingViewModel.swift` — understand how navigation and state work
3. `OnboardingView.swift` — understand the container and transition system
4. `OnboardingWelcomeStep.swift` — simplest step, study the entrance pattern
5. `OnboardingProfileStep.swift` — form inputs, DatePicker, FocusState
6. `OnboardingProfileCardStep.swift` — most advanced: carousel, scrollPosition, scrollTransition
7. `OnboardingCardStep.swift` — multi-phase entrance animation

The best way to learn is to **make small changes and see what breaks.** Try:
- Adding a new case to `OnboardingStep` and see the compiler warn you about unhandled cases
- Removing the `.id(viewModel.currentStep)` from `OnboardingView` and watching transitions break
- Setting `dampingFraction` to 0.3 and seeing the bouncy spring
- Commenting out the 100ms delay in a step's `.task` and seeing the entrance fight the transition
