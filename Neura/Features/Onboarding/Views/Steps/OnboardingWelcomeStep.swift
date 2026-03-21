import SwiftUI

struct OnboardingWelcomeStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Logo
                Image(.n)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                // Text
                VStack(spacing: 14) {
                    Text("All your medical history.\nOne secure place.")
                        .font(.displayXL)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    Text("Private. Offline. Always yours.")
                        .font(.bodyL)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // CTA
            VStack(spacing: 16) {
                Button(action: viewModel.advance) {
                    Text("Get Started")
                        .font(.buttonL)
                        .foregroundStyle(Color.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                Text("Free to use · No account required")
                    .font(.captionS)
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.accent.ignoresSafeArea()
        OnboardingWelcomeStep(viewModel: OnboardingViewModel())
    }
}
