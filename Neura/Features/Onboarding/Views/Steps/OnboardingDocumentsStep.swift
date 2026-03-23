import SwiftUI

struct OnboardingDocumentsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Celebration icon
                ZStack {
                    Circle().fill(Color.accent.opacity(0.08)).frame(width: 120, height: 120)
                    Circle().fill(Color.accent.opacity(0.12)).frame(width: 86, height: 86)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Color.accent)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

                // Text
                VStack(spacing: 12) {
                    Text("You're all set!")
                        .font(.displayL)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your health profile is ready.\nAdd documents anytime from the Docs tab.")
                        .font(.bodyL)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // Feature hints
                VStack(spacing: 8) {
                    hintRow("doc.viewfinder", "Scan documents using your camera")
                    hintRow("staroflife.fill", "Show your emergency card anywhere")
                    hintRow("square.and.arrow.up", "Share your health profile as PDF")
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: viewModel.finalize) {
                    Text("Get Started")
                        .font(.buttonL)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())

                Button("Scan my first document") {
                    UserDefaults.standard.set(true, forKey: "launchScannerOnStart")
                    viewModel.finalize()
                }
                .font(.bodyL)
                .foregroundStyle(Color.black)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private func hintRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accent)
                .frame(width: 20)
            Text(text)
                .font(.bodyS)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }
}

#Preview { OnboardingDocumentsStep(viewModel: OnboardingViewModel()) }
