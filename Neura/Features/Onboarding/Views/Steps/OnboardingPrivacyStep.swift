import SwiftUI

struct OnboardingPrivacyStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Concentric circles + Lock illustration
//            ZStack {
//                ForEach(0..<3, id: \.self) { i in
//                    Circle()
//                        .stroke(Color.stroke.opacity(0.5 - Double(i) * 0.12), lineWidth: 1)
//                        .frame(
//                            width: CGFloat(160 + i * 80),
//                            height: CGFloat(160 + i * 80)
//                        )
//                }
//
//
//            }
//            .accessibilityHidden(true)
            
            Image("lockImage")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 24)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Spacer()

            // Text content
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Onboarding.Privacy.title)
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Onboarding.Privacy.subtitle)
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
