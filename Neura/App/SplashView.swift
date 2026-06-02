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
                LottieView(name: "SplashAnimation") {
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
