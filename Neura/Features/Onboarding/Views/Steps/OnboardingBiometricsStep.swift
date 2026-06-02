import SwiftUI

struct OnboardingBiometricsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon — centered, larger
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.08))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: viewModel.biometricIcon)
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accent)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)

            Spacer()

            // Title + subtitle near continue button
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Onboarding.Biometrics.title)
                    .font(.displayL)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Onboarding.Biometrics.subtitle(viewModel.biometricLabel))
                    .font(.bodyL)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: appeared)

            OnboardingContinueButton(
                action: requestBiometrics,
                title: L10n.Onboarding.Biometrics.enable(viewModel.biometricLabel),
                isLoading: isRequesting,
                leadingIcon: viewModel.biometricIcon,
                secondaryTitle: L10n.Common.maybeLater,
                secondaryAction: viewModel.advance
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: appeared)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            appeared = true
        }
    }

    private func requestBiometrics() {
        isRequesting = true
        Task {
            await viewModel.requestBiometrics()
            isRequesting = false
        }
    }
}

#Preview { OnboardingBiometricsStep(viewModel: OnboardingViewModel()) }
