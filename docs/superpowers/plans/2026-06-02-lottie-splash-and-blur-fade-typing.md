# Lottie Splash + Blur-Fade Word Typing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-built launch splash with a bundled Lottie animation, and add a per-word blur-fade to the onboarding statistics typing reveal.

**Architecture:** Add `lottie-ios` via SPM (hand-edit `project.pbxproj`, mirroring the three existing package entries). Bundle the supplied JSON as a resource, wrap `LottieAnimationView` in a small `UIViewRepresentable`, and swap `SplashView`'s body to play it once and dismiss on completion (struct + `isPresented` binding unchanged). Separately, rewrite `WordTypingEffectModifier` to stack two masked copies of the text so the actively-revealing word fades in *and* sharpens from blur, leaving committed words crisp.

**Tech Stack:** SwiftUI, Lottie (airbnb/lottie-ios), VisionKit-free. iOS app, no test target — verification is `xcodebuild` (simulator) + visual check.

**Verification note:** This project has no unit-test target. "Verify" steps build for the simulator and/or describe the visual result to confirm by eye. Build command used throughout:
```bash
xcodebuild -project Neura.xcodeproj -scheme Neura -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## File Structure

- `Neura.xcodeproj/project.pbxproj` — add Lottie remote package ref, product dependency, build-file, and link it (4 insertions).
- `Neura/Resources/Animations/SplashAnimation.json` — **create** (the supplied animation, bundled via filesystem sync).
- `Neura/Core/UI/Components/LottieView.swift` — **create** the `UIViewRepresentable` wrapper.
- `Neura/App/SplashView.swift` — **modify** body to render the Lottie animation; keep struct + `@Binding`.
- `Neura/Core/Extensions/View+WordTypingEffect.swift` — **modify** the modifier for two-layer blur-fade reveal.

---

### Task 1: Add the Lottie SPM package to the Xcode project

**Files:**
- Modify: `Neura.xcodeproj/project.pbxproj` (4 insertions)

The project uses three invented stable IDs for Lottie (chosen to not collide with existing IDs):
- Remote package reference: `AA10770100000000000000A1`
- Product dependency: `AA10770100000000000000A2`
- Build file: `AA10770100000000000000A3`

- [ ] **Step 1: Add the PBXBuildFile entry**

In the `Begin PBXBuildFile section`, the last entry before `/* End PBXBuildFile section */` is the L10n line. Replace:

```
		BB00A3002F4C801C00BC0001 /* L10n-swift in Frameworks */ = {isa = PBXBuildFile; productRef = BB00A2002F4C801C00BC0001 /* L10n-swift */; };
/* End PBXBuildFile section */
```

with:

```
		BB00A3002F4C801C00BC0001 /* L10n-swift in Frameworks */ = {isa = PBXBuildFile; productRef = BB00A2002F4C801C00BC0001 /* L10n-swift */; };
		AA10770100000000000000A3 /* Lottie in Frameworks */ = {isa = PBXBuildFile; productRef = AA10770100000000000000A2 /* Lottie */; };
/* End PBXBuildFile section */
```

- [ ] **Step 2: Link it in the Frameworks build phase**

In `PBXFrameworksBuildPhase`, replace:

```
				BB00A3002F4C801C00BC0001 /* L10n-swift in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
```

with:

```
				BB00A3002F4C801C00BC0001 /* L10n-swift in Frameworks */,
				AA10770100000000000000A3 /* Lottie in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
```

- [ ] **Step 3: Add to the target's packageProductDependencies**

Replace:

```
				BB00A2002F4C801C00BC0001 /* L10n-swift */,
			);
			productName = Neura;
```

with:

```
				BB00A2002F4C801C00BC0001 /* L10n-swift */,
				AA10770100000000000000A2 /* Lottie */,
			);
			productName = Neura;
```

- [ ] **Step 4: Add to the project's packageReferences**

Replace:

```
				BB00A1002F4C801C00BC0001 /* XCRemoteSwiftPackageReference "L10n-swift" */,
			);
			preferredProjectObjectVersion = 77;
```

with:

```
				BB00A1002F4C801C00BC0001 /* XCRemoteSwiftPackageReference "L10n-swift" */,
				AA10770100000000000000A1 /* XCRemoteSwiftPackageReference "lottie-ios" */,
			);
			preferredProjectObjectVersion = 77;
```

- [ ] **Step 5: Add the XCRemoteSwiftPackageReference**

In the `XCRemoteSwiftPackageReference section`, replace:

```
		BB00A1002F4C801C00BC0001 /* XCRemoteSwiftPackageReference "L10n-swift" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/Decybel07/L10n-swift";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 5.0.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */
```

with:

```
		BB00A1002F4C801C00BC0001 /* XCRemoteSwiftPackageReference "L10n-swift" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/Decybel07/L10n-swift";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 5.0.0;
			};
		};
		AA10770100000000000000A1 /* XCRemoteSwiftPackageReference "lottie-ios" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/airbnb/lottie-ios";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 4.5.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */
```

- [ ] **Step 6: Add the XCSwiftPackageProductDependency**

In the `XCSwiftPackageProductDependency section`, replace:

```
		BB00A2002F4C801C00BC0001 /* L10n-swift */ = {
			isa = XCSwiftPackageProductDependency;
			package = BB00A1002F4C801C00BC0001 /* XCRemoteSwiftPackageReference "L10n-swift" */;
			productName = "L10n-swift";
		};
/* End XCSwiftPackageProductDependency section */
```

with:

```
		BB00A2002F4C801C00BC0001 /* L10n-swift */ = {
			isa = XCSwiftPackageProductDependency;
			package = BB00A1002F4C801C00BC0001 /* XCRemoteSwiftPackageReference "L10n-swift" */;
			productName = "L10n-swift";
		};
		AA10770100000000000000A2 /* Lottie */ = {
			isa = XCSwiftPackageProductDependency;
			package = AA10770100000000000000A1 /* XCRemoteSwiftPackageReference "lottie-ios" */;
			productName = Lottie;
		};
/* End XCSwiftPackageProductDependency section */
```

- [ ] **Step 7: Resolve package dependencies**

Run:
```bash
xcodebuild -resolvePackageDependencies -project Neura.xcodeproj -scheme Neura
```
Expected: resolves `lottie-ios` (a `4.5.x` version) with no "unable to load transferred PIF" / parse errors. If the pbxproj fails to parse, re-check the 6 insertions above for a missing brace or comma.

- [ ] **Step 8: Commit**

```bash
git add Neura.xcodeproj/project.pbxproj Neura.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "build: add lottie-ios SPM package"
```
(If `Package.resolved` lives at a different path, `git add` whatever `git status` shows as new/modified under `Neura.xcodeproj`.)

---

### Task 2: Bundle the splash animation JSON

**Files:**
- Create: `Neura/Resources/Animations/SplashAnimation.json`

- [ ] **Step 1: Copy the animation into the project**

Run:
```bash
mkdir -p Neura/Resources/Animations
cp ~/Downloads/Negative-mask-effect.json Neura/Resources/Animations/SplashAnimation.json
```

- [ ] **Step 2: Verify it is valid JSON and copied**

Run:
```bash
python3 -c "import json; json.load(open('Neura/Resources/Animations/SplashAnimation.json')); print('valid json')"
```
Expected: `valid json`

- [ ] **Step 3: Build and confirm the JSON lands in the app bundle**

Run the standard build command (above). Then:
```bash
find ~/Library/Developer/Xcode/DerivedData/Neura-*/Build/Products/Debug-iphonesimulator/Neura.app -name "SplashAnimation.json"
```
Expected: prints a path to `SplashAnimation.json` inside `Neura.app`.

If it is NOT found, the filesystem-synchronized group did not auto-add the JSON to Copy Bundle Resources. Fallback: open `Neura.xcodeproj` in Xcode, select `SplashAnimation.json`, and check the "Neura" box under Target Membership; rebuild and re-run the `find`.

- [ ] **Step 4: Commit**

```bash
git add Neura/Resources/Animations/SplashAnimation.json
git commit -m "feat: bundle splash Lottie animation"
```

---

### Task 3: Create the LottieView wrapper

**Files:**
- Create: `Neura/Core/UI/Components/LottieView.swift`

- [ ] **Step 1: Write the wrapper**

```swift
import SwiftUI
import Lottie

/// SwiftUI wrapper around Lottie's `LottieAnimationView`.
/// Loads a named animation from the main bundle and plays it.
struct LottieView: UIViewRepresentable {
    /// Bundle resource name (without the `.json` extension).
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    /// Called once when a `.playOnce` animation finishes playing.
    var onComplete: () -> Void = {}

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: name)
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        animationView.play { finished in
            if finished { onComplete() }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the standard build command. Expected: build succeeds with no `Cannot find 'LottieAnimationView'` errors (confirms Task 1 linked the product).

- [ ] **Step 3: Commit**

```bash
git add Neura/Core/UI/Components/LottieView.swift
git commit -m "feat: add LottieView SwiftUI wrapper"
```

---

### Task 4: Rewrite SplashView to play the Lottie animation

**Files:**
- Modify: `Neura/App/SplashView.swift` (full body replacement; struct name + `@Binding var isPresented` unchanged)

- [ ] **Step 1: Replace the entire file contents**

```swift
import SwiftUI

struct SplashView: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var overallOpacity: Double = 1

    var body: some View {
        ZStack {
            // Matches the animation's own off-white backing — prevents any flash.
            Color.backgroundPrimary
                .ignoresSafeArea()

            if reduceMotion {
                // Branded static fallback — no playback for reduce-motion users.
                Text("Neura")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.accent)
            } else {
                LottieView(name: "SplashAnimation", loopMode: .playOnce) {
                    dismiss()
                }
                .ignoresSafeArea()
            }
        }
        .opacity(overallOpacity)
        .task {
            // Reduce-motion: no completion callback fires, so dismiss on a short timer.
            if reduceMotion {
                try? await Task.sleep(for: .milliseconds(1000))
                dismiss()
            }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.3)) {
            overallOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            isPresented = false
        }
    }
}

#Preview {
    SplashView(isPresented: .constant(true))
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the standard build command. Expected: build succeeds.

- [ ] **Step 3: Visual verification**

Run the app in the simulator (launch as a returning signed-in user, or complete onboarding). Expected: off-white screen, the "Neura" wordmark reveal plays once (~4s), then the splash fades out revealing the dashboard. Confirm there is no orange/white flash at the start and no hang after the animation ends. With Reduce Motion enabled (Simulator → Settings → Accessibility → Motion), expect the static "Neura" text for ~1s then fade out.

- [ ] **Step 4: Commit**

```bash
git add Neura/App/SplashView.swift
git commit -m "feat: play Lottie animation in splash screen"
```

---

### Task 5: Add per-word blur-fade to the typing reveal

**Files:**
- Modify: `Neura/Core/Extensions/View+WordTypingEffect.swift`

Behavior change only: keep the typing timing, `visibleWordCount`/`revealProgress` state, callbacks, and word-splitting identical. Replace the single `.mask` with a `ZStack` of two masked copies of `content`: committed words (sharp) + the current word (faded and blurred while revealing). Add an `accessibilityReduceMotion` guard that zeroes the blur.

- [ ] **Step 1: Replace the `WordTypingEffectModifier` struct (lines 23-122)**

Replace the entire `struct WordTypingEffectModifier: ViewModifier { ... }` block with:

```swift
struct WordTypingEffectModifier: ViewModifier {
    @Binding var shouldStartTyping: Bool
    let fullText: String
    let font: Font
    let wordsPerSecond: Double
    let onTypingCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Index of the last fully committed (fully visible) word
    @State private var visibleWordCount: Int = 0
    // Reveal progress of the word currently fading in (0 → 1)
    @State private var revealProgress: CGFloat = 0
    @State private var typingTask: Task<Void, Never>? = nil

    private var words: [String] {
        fullText.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    func body(content: Content) -> some View {
        ZStack {
            // Layer 1 — committed words: sharp, fully opaque.
            content.mask { committedMask }

            // Layer 2 — current word: fades in AND sharpens from blur.
            content
                .mask { currentWordMask }
                .opacity(Double(revealProgress))
                .blur(radius: reduceMotion ? 0 : (1 - revealProgress) * 6)
        }
        .onAppear { if shouldStartTyping { startTyping() } }
        .onChange(of: shouldStartTyping) { _, new in if new { startTyping() } }
    }

    // Number of characters spanned by the first `count` words joined with spaces.
    private func charCount(upToWord count: Int) -> Int {
        words.prefix(count).joined(separator: " ").count
    }

    // Mask revealing words[0..<visibleWordCount] in white, rest clear.
    private var committedMask: some View {
        var attributed = AttributedString(fullText)
        attributed.foregroundColor = .clear
        if visibleWordCount > 0 {
            let endChar = charCount(upToWord: visibleWordCount)
            let endIdx = attributed.index(attributed.startIndex, offsetByCharacters: endChar)
            attributed[attributed.startIndex..<endIdx].foregroundColor = .white
        }
        return Text(attributed)
            .font(font)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // Mask revealing ONLY words[visibleWordCount] in white (opacity/blur applied by the layer).
    private var currentWordMask: some View {
        let wordList = words
        var attributed = AttributedString(fullText)
        attributed.foregroundColor = .clear
        if visibleWordCount < wordList.count {
            let chunkStart = visibleWordCount == 0 ? 0 : charCount(upToWord: visibleWordCount)
            let chunkEnd = charCount(upToWord: visibleWordCount + 1)
            if chunkStart < chunkEnd, chunkEnd <= fullText.count {
                let startIdx = attributed.index(attributed.startIndex, offsetByCharacters: chunkStart)
                let endIdx = attributed.index(attributed.startIndex, offsetByCharacters: chunkEnd)
                attributed[startIdx..<endIdx].foregroundColor = .white
            }
        }
        return Text(attributed)
            .font(font)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func startTyping() {
        typingTask?.cancel()
        let wordList = words
        guard !wordList.isEmpty else { return }

        let interval = 1.0 / max(wordsPerSecond, 0.5)
        // Longer fade (85% of interval) gives the blur room to read before the next word.
        let fadeDuration = interval * 0.85

        typingTask = Task { @MainActor in
            visibleWordCount = 0
            revealProgress = 0

            for i in 0..<wordList.count {
                if Task.isCancelled { return }

                // Soft blur-fade-in for this word.
                withAnimation(.easeOut(duration: fadeDuration)) {
                    revealProgress = 1
                }

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }

                // Commit — word joins the sharp committed region, reset for next word.
                visibleWordCount = i + 1
                revealProgress = 0

                if i == wordList.count - 1 {
                    onTypingCompleted()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the standard build command. Expected: build succeeds.

- [ ] **Step 3: Visual verification**

Run the app, advance to the onboarding statistics step. Expected: the body text reveals word-by-word; each word drifts in blurred + faint, then sharpens to crisp and stays crisp once committed (committed words are never blurry). The badge → button chain still fires after the last word. With Reduce Motion on, words still reveal in sequence but with no blur.

- [ ] **Step 4: Commit**

```bash
git add Neura/Core/Extensions/View+WordTypingEffect.swift
git commit -m "feat: blur-fade per-word reveal in typing effect"
```

---

## Self-Review

- **Spec coverage:**
  - Lottie via SPM → Task 1. ✓
  - Bundle JSON → Task 2. ✓
  - LottieView wrapper → Task 3. ✓
  - SplashView body swap, dismiss on completion, off-white backing, reduce-motion fallback, struct/binding kept → Task 4. ✓
  - Two-layer masked blur-fade, timing/callbacks kept, easing softened + fade lengthened, reduce-motion zeroes blur, typing-text-only scope → Task 5. ✓
  - CardVideo rename was completed separately (outside this plan) and is intentionally not included.
- **Placeholders:** none — all code and commands are concrete.
- **Type consistency:** `LottieView(name:loopMode:onComplete:)` defined in Task 3 is called identically in Task 4. `charCount(upToWord:)`, `committedMask`, `currentWordMask`, `visibleWordCount`, `revealProgress` are consistent within Task 5. `dismiss()` defined and called within Task 4.
- **Risk:** the only fragile step is the pbxproj hand-edit (Task 1) and JSON auto-bundling (Task 2) — both have explicit verification + fallback steps.
