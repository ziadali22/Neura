import SwiftUI

struct OnboardingHealthDataStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Icon + title
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color(.systemGreen).opacity(0.1)).frame(width: 80, height: 80)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(.systemGreen))
                    }
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: 8) {
                        Text(L10n.Onboarding.HealthData.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(L10n.Onboarding.HealthData.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                }

                // Data cards
                VStack(spacing: 12) {
                    if let height = viewModel.healthKitData?.height {
                        dataRow("ruler", L10n.Onboarding.HealthData.height, height)
                    }
                    if let weight = viewModel.healthKitData?.weight {
                        dataRow("scalemass", L10n.Onboarding.HealthData.weight, weight)
                    }
                    if let sex = viewModel.healthKitData?.biologicalSex {
                        dataRow("figure.stand", L10n.Onboarding.HealthData.biologicalSex, sex)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }

            Spacer()
            Spacer()

            OnboardingContinueButton(
                action: viewModel.advance,
                title: L10n.Onboarding.HealthData.useThisData,
                secondaryTitle: L10n.Onboarding.HealthData.enterManually
            )
            .opacity(appeared ? 1 : 0)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private func dataRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accent.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
            Text(label)
                .font(.bodyL)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(12)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview { OnboardingHealthDataStep(viewModel: OnboardingViewModel()) }
