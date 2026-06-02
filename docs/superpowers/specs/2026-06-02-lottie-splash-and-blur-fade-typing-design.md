# Design: Lottie Splash Screen + Blur-Fade Word Typing

Date: 2026-06-02
Branch: feature/new-onboarding

Two related onboarding/launch polish changes:

1. Replace the hand-built launch splash with a bundled Lottie animation.
2. Enhance the word-by-word typing reveal in the onboarding statistics step with a per-word blur-fade.

---

## 1. Lottie Splash Screen

### Context

- `NeuraApp` shows a `SplashView(isPresented:)` overlay in a `ZStack` on top of the
  root content. `showSplash` is set true on launch for returning users
  (`done && signedIn`) and after onboarding completes. See `Neura/App/NeuraApp.swift:52`
  and `:76`.
- The current `SplashView` (`Neura/App/SplashView.swift`) is a hand-built orange-gradient
  + logo spring + wordmark fade, dismissing itself via `isPresented = false` after a timed
  sequence, with a `reduceMotion` fallback.
- The app already uses SPM (`firebase-ios-sdk`, `GoogleSignIn-iOS`, `L10n-swift`) declared
  in `Neura.xcodeproj/project.pbxproj`. CLAUDE.md's "no dependencies" note is stale.
- The supplied animation (`Negative-mask-effect.json`) is a ~4s (240 frames @ 60fps) "Neura"
  wordmark reveal: an off-white `#FCFAF8` backing with an orange `#FF5A00` mask sweep that
  reveals the letters.

### Decisions

- **Add Lottie via SPM.** Add `lottie-ios` (https://github.com/airbnb/lottie-ios), product
  `Lottie`, as an `XCRemoteSwiftPackageReference` pinned `upToNextMajorVersion`, mirroring
  the existing package entries. Link the `Lottie` product to the Neura app target.
- **Bundle the animation.** Copy the JSON into `Neura/Resources/Animations/SplashAnimation.json`
  so it ships as a bundle resource (filesystem sync picks it up).
- **Reuse `SplashView`.** Keep the `SplashView` struct, its `@Binding var isPresented`, and
  all of `NeuraApp`'s trigger/overlay wiring unchanged. Only the *body* changes. The old
  gradient/logo/wordmark animation code is removed.
- **Dismiss when the animation finishes.** Play once and dismiss on Lottie's completion
  callback (not a fixed timer).

### Components

- **`LottieView` (`Neura/Core/UI/Components/LottieView.swift`)** — a small
  `UIViewRepresentable` wrapping Lottie's `LottieAnimationView`:
  - Inputs: animation file name, `loopMode` (default `.playOnce`), `onComplete` callback.
  - Loads the named animation from the main bundle, sets `contentMode = .scaleAspectFit`,
    plays on appear, invokes `onComplete` from the play completion handler.
- **`SplashView` rewritten body:**
  - `Color.backgroundPrimary` (#FCFAF8) edge-to-edge backing to match the animation's own
    off-white background — prevents any flash.
  - `LottieView(name: "SplashAnimation", onComplete:)` centered.
  - On completion: animate `overallOpacity → 0`, then set `isPresented = false` (preserves
    the graceful fade hand-off to the content beneath).
  - **Reduce Motion:** under `accessibilityReduceMotion`, skip playback, show a brief static
    branded frame (final frame of the animation), and dismiss after ~1s.

### Data flow

`NeuraApp` sets `showSplash = true` → `SplashView` appears → `LottieView` plays once →
`onComplete` → fade out → `isPresented = false` → overlay removed, root content visible.

---

## 2. Blur-Fade Word Typing

### Context

- `OnboardingStatisticsStep` (`Neura/Features/Onboarding/Views/Steps/OnboardingStatisticsStep.swift`)
  reveals its body text with `.wordTypingEffect(...)`.
- `WordTypingEffectModifier` (`Neura/Core/Extensions/View+WordTypingEffect.swift`) renders the
  full `Text` and reveals it word-by-word through a single per-character `AttributedString`
  **mask**: `revealProgress` (0→1, `easeInOut`) fades each word's opacity in, then commits it
  to the fully-visible region (`visibleWordCount`).
- The reveal is opacity-only; there is no blur.

### Decision

Add a per-word **blur + fade** reveal while keeping the existing mask architecture, timing,
callbacks, and `reduceMotion` path unchanged. No flow layout, no change to
`OnboardingStatisticsStep`. Scope: the typing body text only (number and badge untouched).

### Approach — two masked copies stacked in a `ZStack`

Both copies are the same full `Text` (identical layout → perfect overlay; wrapping/centering
preserved):

- **Layer 1 — committed words:** `content` masked to `words[0..<visibleWordCount]`, sharp,
  fully opaque (current behavior).
- **Layer 2 — current word:** `content` masked to *only* `words[visibleWordCount]`, with
  `.blur(radius: (1 - revealProgress) * 6)` and `.opacity(revealProgress)`. As `revealProgress`
  animates 0→1, the single active word fades in and sharpens from a 6pt blur to crisp, then
  commits to Layer 1.

Easing softened to `.easeOut` and the fade duration lengthened slightly so the blur has room
to read. Only the actively-revealing word is ever blurred; committed text stays crisp.

`reduceMotion` path (instant full reveal) is untouched.

---

## Out of scope / YAGNI

- No new splash trigger logic or timing config in `NeuraApp`.
- No blur-fade on the statistics number or Harvard badge.
- No general onboarding animation system changes.
