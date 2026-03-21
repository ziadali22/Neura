import SwiftUI

struct OnboardingPrivacyStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accent.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.accent)
                        }
                        .padding(.bottom, 4)

                        Text("Your data is\n100% private")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)

                        Text("Neura never collects or transmits your health data.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    // Benefit cards
                    VStack(spacing: 12) {
                        privacyCard(
                            icon: "iphone.and.arrow.forward",
                            iconColor: Color.accent,
                            title: "Never leaves your device",
                            subtitle: "All health data is stored locally on your iPhone. No servers, no syncing."
                        )
                        privacyCard(
                            icon: "faceid",
                            iconColor: Color(hex: "007AFF"),
                            title: "Protected with biometrics",
                            subtitle: "Face ID or Touch ID is required to access your health profile."
                        )
                        privacyCard(
                            icon: "wifi.slash",
                            iconColor: Color(hex: "34C759"),
                            title: "Works completely offline",
                            subtitle: "No internet needed. Your data is always available, anywhere."
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)

            continueButton
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private func privacyCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var continueButton: some View {
        Button(action: viewModel.advance) {
            Text("I understand — Continue")
                .font(.buttonL)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

#Preview { OnboardingPrivacyStep(viewModel: OnboardingViewModel()) }
