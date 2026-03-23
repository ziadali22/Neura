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
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemPink).opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Color(.systemPink))
                        }
                        Text("Connect to\nApple Health")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text("Automatically fill in your health profile without typing.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Benefits
                    VStack(spacing: 12) {
                        benefitRow("ruler", "Import your height", "Pulled from Apple Health automatically")
                        benefitRow("scalemass", "Import your weight", "Stays up to date with your latest reading")
                        benefitRow("figure.stand", "Import biological sex", "Used for medical context in reports")
                    }

                    // Privacy note
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                        Text("You control what Neura reads. Data stays on your device and is never shared.")
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

            // Actions
            VStack(spacing: 12) {
                Button {
                    viewModel.requestHealthKit()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.healthKitStatus == .requesting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                        }
                        Text("Connect Apple Health")
                            .font(.buttonL)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(viewModel.healthKitStatus == .requesting)

                Button("Not now") { viewModel.advance() }
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func benefitRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemPink).opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(.systemPink))
            }
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
