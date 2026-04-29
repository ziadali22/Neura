import SwiftUI

struct OnboardingWelcomeStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showError = false
    @State private var loadingProvider: AuthProvider?

    enum AuthProvider { case apple, google }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            Image(.logo)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fill)
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()

            // Bottom content
            VStack(spacing: 0) {
                // Title + subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Neura")
                        .font(.displayL)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Store, organize, and share your medical records in one secure place.")
                        .font(.bodyL)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        loadingProvider = .apple
                        viewModel.signInWithApple()
                    } label: {
                        HStack(spacing: 8) {
                            if loadingProvider == .apple && viewModel.isSigningIn {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Continue with Apple")
                                    .font(.buttonL)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .clipShape(.rect(cornerRadius: 28))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(viewModel.isSigningIn)
                    .accessibilityLabel("Continue with Apple")

                    Button {
                        loadingProvider = .google
                        viewModel.signInWithGoogle()
                    } label: {
                        HStack(spacing: 8) {
                            if loadingProvider == .google && viewModel.isSigningIn {
                                ProgressView().tint(Color.textPrimary)
                            } else {
                                Image(.googleIcon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .font(.buttonL)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 28))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(viewModel.isSigningIn)
                    .accessibilityLabel("Continue with Google")

                    // Error message
                    if let error = viewModel.authError {
                        Text(error)
                            .font(.captionS)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                // Footer
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("End-to-end encrypted")
                        .font(.captionS)
                }
                .foregroundStyle(.black)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(reduceMotion ? .none : .spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "FFBD82"), Color(hex: "FF7040"), Color(hex: "D6391A")],
            startPoint: .topTrailing, endPoint: .bottomLeading
        )
        .ignoresSafeArea()
        OnboardingWelcomeStep(viewModel: OnboardingViewModel())
    }
}
