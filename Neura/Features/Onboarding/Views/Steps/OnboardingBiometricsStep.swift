import SwiftUI

struct OnboardingBiometricsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 40) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accent.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(Color.accent.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: viewModel.biometricIcon)
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accent)
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

                // Text
                VStack(spacing: 12) {
                    Text(L10n.Onboarding.Biometrics.title)
                        .font(.displayL)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(L10n.Onboarding.Biometrics.subtitle(viewModel.biometricLabel))
                        .font(.bodyL)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

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
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
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
