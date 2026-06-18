import SwiftUI

struct SplashView: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var overallOpacity: Double = 1
    @State private var overallScale: CGFloat = 1
    @State private var overallBlur: CGFloat = 0
    @State private var lottieOpacity: Double = 1

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
                LottieView(name: "SplashAnimation", animationSpeed: 1.3) {
                    dismiss()
                }
                .frame(width: 320, height: 320)
                .opacity(lottieOpacity)
            }
        }
        .scaleEffect(overallScale)
        .blur(radius: overallBlur)
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
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.35)) {
                overallOpacity = 0
            }
            finish(after: .milliseconds(380))
            return
        }

        // Stage 1 — fade the animation mark out first, leaving only the plain
        // off-white background. This decouples the Lottie's exit from the
        // screen hand-off so the transition reads as one calm motion.
        withAnimation(.easeOut(duration: 0.3)) {
            lottieOpacity = 0
        }

        // Stage 2 — once the mark is gone, zoom-and-blur the (now empty)
        // background away to reveal the content beneath.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeIn(duration: 0.5)) {
                overallScale = 1.12
                overallBlur = 10
                overallOpacity = 0
            }
            finish(after: .milliseconds(500))
        }
    }

    private func finish(after delay: Duration) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            isPresented = false
        }
    }
}

#Preview {
    SplashView(isPresented: .constant(true))
}
