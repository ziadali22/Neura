import SwiftUI

struct OnboardingCalendarStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("calendar-onboarding")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 24)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Onboarding.CalendarStep.title)
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Onboarding.CalendarStep.subtitle)
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
    OnboardingCalendarStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
