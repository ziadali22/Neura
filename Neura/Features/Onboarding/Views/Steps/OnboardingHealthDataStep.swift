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
                        Text("We found your data")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Here's what we pulled from Apple Health:")
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
                        dataRow("ruler", "Height", height)
                    }
                    if let weight = viewModel.healthKitData?.weight {
                        dataRow("scalemass", "Weight", weight)
                    }
                    if let sex = viewModel.healthKitData?.biologicalSex {
                        dataRow("figure.stand", "Biological Sex", sex)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }

            Spacer()
            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: viewModel.advance) {
                    Text("Use This Data")
                        .font(.buttonL)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())

                Button("Enter manually instead") { viewModel.advance() }
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
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
