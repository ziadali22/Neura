import SwiftUI

/// Reusable full-width continue button used across all onboarding steps.
/// Pass `isEnabled: false` to show a dimmed, non-interactive state
/// (e.g. while an animation is playing or required input is missing).
struct OnboardingContinueButton: View {
    let action: () -> Void
    var title: String = "Continue"
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonL)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? Color.black : Color.textTertiary)
                .clipShape(.rect(cornerRadius: 28))
                .shadow(color: isEnabled ? .black.opacity(0.15) : .clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .animation(.easeInOut(duration: 0.3), value: isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        OnboardingContinueButton(action: {})
        OnboardingContinueButton(action: {}, isEnabled: false)
        OnboardingContinueButton(action: {}, title: "Get Started")
    }
    .padding()
    .background(Color.backgroundPrimary)
}
