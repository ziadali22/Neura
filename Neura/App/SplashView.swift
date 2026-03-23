import SwiftUI

struct SplashView: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoScale: Double = 0.55
    @State private var logoOpacity: Double = 0
    @State private var glowScale: Double = 0.4
    @State private var glowOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var overallOpacity: Double = 1

    var body: some View {
        ZStack {
            // Rich brand gradient — matches the welcome onboarding step
            LinearGradient(
                colors: [
                    Color(hex: "FFB566"),
                    Color(hex: "FF5A00"),
                    Color(hex: "CC3500")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle decorative circle in top-right
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 320, height: 320)
                .offset(x: 100, y: -180)
                .ignoresSafeArea()

            // Soft radial bloom behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .blur(radius: 18)

            // Logo + wordmark
            VStack(spacing: 16) {
                Image(.logo)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .accessibilityHidden(true)

                Text("Neura")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(wordmarkOpacity)
                    .accessibilityLabel("Neura")
            }
        }
        .opacity(overallOpacity)
        .task { await animate() }
    }

    // MARK: - Animation

    private func animate() async {
        if reduceMotion {
            await animateReducedMotion()
        } else {
            await animateFull()
        }
    }

    private func animateFull() async {
        // 1 — logo springs in with glow
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            logoScale = 1
            logoOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.7)) {
            glowScale = 1
            glowOpacity = 1
        }

        // 2 — wordmark fades up slightly after logo settles
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.35)) {
            wordmarkOpacity = 1
        }

        // 3 — hold at full presence
        try? await Task.sleep(for: .milliseconds(950))

        // 4 — exit: logo zooms forward and fades, glow collapses
        withAnimation(.easeIn(duration: 0.28)) {
            logoScale = 1.18
            logoOpacity = 0
            wordmarkOpacity = 0
            glowOpacity = 0
        }

        // 5 — background fades last, revealing content beneath
        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.easeIn(duration: 0.3)) {
            overallOpacity = 0
        }

        try? await Task.sleep(for: .milliseconds(320))
        isPresented = false
    }

    private func animateReducedMotion() async {
        withAnimation(.easeIn(duration: 0.25)) {
            logoOpacity = 1
            wordmarkOpacity = 1
            glowOpacity = 1
        }
        try? await Task.sleep(for: .milliseconds(1400))
        withAnimation(.easeOut(duration: 0.35)) {
            overallOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(380))
        isPresented = false
    }
}

#Preview {
    SplashView(isPresented: .constant(true))
}
