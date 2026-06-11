import SwiftUI

/// "Stay updated" — asks the user to allow notifications so Neura can send
/// gentle reminders to keep their health profile up to date.
struct OnboardingNotificationsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showImage = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Hero: phone mockup with the sample notification
            Image("notifications")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .opacity(showImage ? 1 : 0)
                .scaleEffect(showImage ? 1 : 0.9)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8),
                    value: showImage
                )

            Spacer(minLength: 24)

            // Text block
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Onboarding.Notifications.title)
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                        value: showTitle
                    )

                Text(L10n.Onboarding.Notifications.subtitle)
                    .font(.bodyL)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                        value: showSubtitle
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            OnboardingContinueButton(
                action: viewModel.requestNotifications,
                title: L10n.Onboarding.Notifications.allow,
                secondaryTitle: L10n.Common.notNow,
                secondaryAction: viewModel.skip
            )
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 24)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                value: showButton
            )
        }
        .task { await runAnimationSequence() }
    }

    @MainActor
    private func runAnimationSequence() async {
        guard !reduceMotion else {
            showImage = true; showTitle = true; showSubtitle = true; showButton = true
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        showImage = true
        try? await Task.sleep(for: .milliseconds(300))
        showTitle = true
        try? await Task.sleep(for: .milliseconds(180))
        showSubtitle = true
        try? await Task.sleep(for: .milliseconds(180))
        showButton = true
    }
}

#Preview {
    OnboardingNotificationsStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
