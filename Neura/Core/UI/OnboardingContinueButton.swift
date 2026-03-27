import SwiftUI

/// Full-width primary + optional secondary action button used across all onboarding steps.
///
/// - `isEnabled`: dims the primary button and disables interaction (e.g. required input missing).
/// - `isLoading`: shows a spinner inside the primary button and disables it (e.g. async request running).
/// - `leadingIcon`: SF Symbol name shown left of the title (e.g. "heart.fill", "faceid").
/// - `secondaryTitle` / `secondaryAction`: renders a plain text button below the primary.
///   If `secondaryAction` is nil, tapping the secondary calls `action`.
struct OnboardingContinueButton: View {
    let action: () -> Void
    var title: String = "Continue"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var leadingIcon: String? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    private var effectivelyEnabled: Bool { isEnabled && !isLoading }

    private var primaryBackground: Color {
        isLoading ? Color.black : (effectivelyEnabled ? Color.black : Color.textTertiary)
    }

    var body: some View {
        VStack(spacing: 16) {
            Button(action: action) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else if let icon = leadingIcon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.buttonL)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(primaryBackground)
                .clipShape(.rect(cornerRadius: 28))
                .shadow(
                    color: effectivelyEnabled ? .black.opacity(0.15) : .clear,
                    radius: 10, x: 0, y: 5
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!effectivelyEnabled)
            .animation(.easeInOut(duration: 0.25), value: effectivelyEnabled)
            .animation(.easeInOut(duration: 0.2), value: isLoading)

            if let secondary = secondaryTitle {
                Button(secondary, action: secondaryAction ?? action)
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

#Preview {
    VStack(spacing: 0) {
        OnboardingContinueButton(action: {})
        OnboardingContinueButton(action: {}, title: "Get Started", secondaryTitle: "Skip for now")
        OnboardingContinueButton(
            action: {},
            title: "Connect Apple Health",
            isLoading: true,
            leadingIcon: "heart.fill",
            secondaryTitle: "Not now"
        )
        OnboardingContinueButton(action: {}, isEnabled: false, secondaryTitle: "Maybe later")
    }
    .background(Color.backgroundPrimary)
}
