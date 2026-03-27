import SwiftUI

struct OnboardingPrivacyStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Concentric circles + Lock illustration
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.stroke.opacity(0.5 - Double(i) * 0.12), lineWidth: 1)
                        .frame(
                            width: CGFloat(160 + i * 80),
                            height: CGFloat(160 + i * 80)
                        )
                }

                Image(.lock)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
            }
            .accessibilityHidden(true)

            Spacer()

            // Text content
            VStack(alignment: .leading, spacing: 12) {
                Text("Your health data is\nprivate and secure")
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)

                Text("Your documents are encrypted and stored securely. Only you control what you share.")
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
    OnboardingPrivacyStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
