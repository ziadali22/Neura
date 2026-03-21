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
                    Text("Protect your\nhealth profile")
                        .font(.displayL)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Use \(viewModel.biometricLabel) to lock your profile so only you can access it.")
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

            // Actions
            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        await viewModel.requestBiometrics()
                        isRequesting = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: viewModel.biometricIcon)
                                .font(.system(size: 17))
                        }
                        Text("Enable \(viewModel.biometricLabel)")
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
                .disabled(isRequesting)

                Button("Maybe later") { viewModel.advance() }
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }
}

#Preview { OnboardingBiometricsStep(viewModel: OnboardingViewModel()) }
