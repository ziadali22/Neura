import SwiftUI

struct OnboardingHealthKitStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Image("appleHealthIcon")
                            .resizable()
                            .frame(width: 64, height: 64)
                        
                        Text(L10n.Onboarding.HealthKit.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text(L10n.Onboarding.HealthKit.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Benefits
                    VStack(spacing: 12) {
                        benefitRow("HeightIcon", L10n.Onboarding.HealthKit.importHeight, L10n.Onboarding.HealthKit.importHeightSub)
                        benefitRow("WeightIcon", L10n.Onboarding.HealthKit.importWeight, L10n.Onboarding.HealthKit.importWeightSub)
                        benefitRow("SexIcon", L10n.Onboarding.HealthKit.importSex, L10n.Onboarding.HealthKit.importSexSub)
                    }

                    // Privacy note
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                        Text(L10n.Onboarding.HealthKit.privacyNote)
                            .font(.bodyS)
                            .foregroundStyle(Color.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.surfaceWhite)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)

            OnboardingContinueButton(
                action: viewModel.requestHealthKit,
                title: L10n.Onboarding.HealthKit.connect,
                isLoading: viewModel.healthKitStatus == .requesting,
                leadingIcon: "heart.fill",
                secondaryTitle: L10n.Common.notNow,
                secondaryAction: viewModel.skip
            )
            .opacity(appeared ? 1 : 0)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func benefitRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(.systemPink))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headingXS).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.bodyS).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(.systemGreen))
        }
        .padding(12)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

#Preview { OnboardingHealthKitStep(viewModel: OnboardingViewModel()) }
