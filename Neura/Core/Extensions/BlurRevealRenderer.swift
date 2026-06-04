//
//  BlurRevealRenderer.swift
//  Neura
//
//  Created by Ziad Ali Khalil on 04/06/2026.
//


//
//  BlurRevealText.swift
//
//  Per-character blur + fade reveal for any Text, driven by a TextRenderer.
//  Works with multiline, wrapping, alignment and any font — no manual glyph layout.
//
//  Requires iOS 18 / macOS 15 (TextRenderer).
//
//  Usage:
//      Text("Welcome to Girltalk")
//          .font(.system(size: 40, weight: .semibold, design: .serif))
//          .blurReveal()                 // auto-plays on appear
//
//      // Replay when a value changes:
//      Text(headline)
//          .blurReveal(trigger: stepIndex)
//
//      // Tune it:
//      Text(headline)
//          .blurReveal(animation: .linear(duration: 1.4),
//                      blurRadius: 10, yOffset: 10, glyphWindow: 0.4)
//

import SwiftUI

// MARK: - Renderer

@available(iOS 18.0, macOS 15.0, *)
struct BlurRevealRenderer: TextRenderer, Animatable {

    /// 0 = fully hidden, 1 = fully revealed.
    var progress: Double

    /// Max blur applied to a glyph at the start of its reveal.
    var blurRadius: CGFloat = 8

    /// How far each glyph drifts up (in points) before settling.
    var yOffset: CGFloat = 8

    /// Fraction of the whole timeline a single glyph spends resolving.
    /// Larger = more glyphs mid-reveal at once (softer, more overlap).
    var glyphWindow: Double = 0.35

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // Flatten lines -> runs -> per-glyph slices. Wrapping is already resolved here.
        let slices = layout.flatMap { line in line.flatMap { run in run } }
        let count = slices.count
        guard count > 0 else { return }

        let window = max(0.0001, glyphWindow)
        let lastStart = max(0.0001, 1 - window)

        for (index, slice) in slices.enumerated() {
            // Stagger: glyph 0 starts at t=0, last glyph starts at (1 - window),
            // so the final glyph also finishes exactly at progress == 1.
            let start = count > 1
                ? lastStart * Double(index) / Double(count - 1)
                : 0
            let local = ((progress - start) / window).clamped(to: 0...1)
            let eased = smoothstep(local)

            var glyph = context
            glyph.opacity = eased
            glyph.translateBy(x: 0, y: yOffset * (1 - eased))
            if blurRadius > 0, eased < 1 {
                glyph.addFilter(.blur(radius: blurRadius * (1 - eased)))
            }
            glyph.draw(slice)
        }
    }

    private func smoothstep(_ x: Double) -> Double {
        let t = x.clamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Modifier

@available(iOS 18.0, macOS 15.0, *)
struct BlurRevealModifier<Trigger: Equatable>: ViewModifier {

    let trigger: Trigger
    let animation: Animation
    let delay: Double
    let blurRadius: CGFloat
    let yOffset: CGFloat
    let glyphWindow: Double

    @State private var progress: Double = 0

    func body(content: Content) -> some View {
        content
            .textRenderer(
                BlurRevealRenderer(
                    progress: progress,
                    blurRadius: blurRadius,
                    yOffset: yOffset,
                    glyphWindow: glyphWindow
                )
            )
            .onAppear(perform: play)
            .onChange(of: trigger) { _, _ in
                progress = 0
                play()
            }
    }

    private func play() {
        withAnimation(animation.delay(delay)) {
            progress = 1
        }
    }
}

// MARK: - View API

@available(iOS 18.0, macOS 15.0, *)
extension View {
    /// Reveals the receiver's text one glyph at a time with a blur + fade + drift.
    ///
    /// - Parameters:
    ///   - trigger: Change this value to replay the animation (e.g. an onboarding step).
    ///   - animation: Timing of the overall reveal. Linear gives an even, typewriter-like cadence.
    ///   - delay: Seconds to wait before starting.
    ///   - blurRadius: Starting blur per glyph.
    ///   - yOffset: Upward drift per glyph before settling.
    ///   - glyphWindow: How much of the timeline each glyph takes to resolve (overlap amount).
    func blurReveal<Trigger: Equatable>(
        trigger: Trigger = 0,
        animation: Animation = .linear(duration: 1.1),
        delay: Double = 0,
        blurRadius: CGFloat = 8,
        yOffset: CGFloat = 8,
        glyphWindow: Double = 0.35
    ) -> some View {
        modifier(
            BlurRevealModifier(
                trigger: trigger,
                animation: animation,
                delay: delay,
                blurRadius: blurRadius,
                yOffset: yOffset,
                glyphWindow: glyphWindow
            )
        )
    }
}

// MARK: - Utilities

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

@available(iOS 18.0, macOS 15.0, *)
#Preview {
    struct Demo: View {
        @State private var replay = 0
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text("Welcome to Girltalk")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .blurReveal(trigger: replay, animation: .linear(duration: 1.4),
                                          blurRadius: 10, yOffset: 10, glyphWindow: 0.4)
//                    .blurReveal(trigger: replay)

                Text("With over 200.00 women, Girltalk is your guide to decode modern relations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blurReveal(trigger: replay,
                                animation: .linear(duration: 1.0),
                                delay: 0.5,
                                blurRadius: 6)

                Spacer()
                Button("Replay") { replay += 1 }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.96))
        }
    }
    return Demo()
}
