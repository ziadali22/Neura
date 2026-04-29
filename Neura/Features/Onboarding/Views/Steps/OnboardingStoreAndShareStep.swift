import SwiftUI

struct OnboardingStoreAndShareStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // FilesCard illustration
            Image(.fileCard)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 24)
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)

            Spacer()

            // Text content
            VStack(alignment: .leading, spacing: 12) {
                Text("Store and share your\nmedical records")
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)

                Text("Upload and access your documents anytime. Share them with your doctor in seconds.")
                    .font(.bodyL)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            OnboardingContinueButton(action: viewModel.advance)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}

#Preview {
    OnboardingStoreAndShareStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
