import SwiftUI

struct OnboardingStatisticsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation state

    /// "12 million" springs from scale=3 down to scale=1
    @State private var numberOpacity: CGFloat = 0
    @State private var numberScale: CGFloat = 3

    @State private var showBody: Bool = false
    @State private var showBadge: Bool = false
    @State private var showButton: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            statBlock
                .padding(.horizontal, 32)

            Spacer()

            continueButton
        }
        .task { await runAnimationSequence() }
    }

    // MARK: - Stat block

    private var statBlock: some View {
        VStack(spacing: 16) {
            // Big spring number
            Text(L10n.Onboarding.Statistics.number)
                .font(.system(size: 52, weight: .bold, design: .default))
                .foregroundStyle(Color.accent)
                .opacity(numberOpacity)
                .scaleEffect(numberScale)

            // Body text
            Text(L10n.Onboarding.Statistics.body)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showBody ? 1 : 0)
                .offset(y: showBody ? 0 : 24)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                    value: showBody
                )

            // Harvard badge
            harvardBadge
                .padding(.top, 4)
                .opacity(showBadge ? 1 : 0)
                .offset(y: showBadge ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: showBadge
                )
        }
    }

    // MARK: - Harvard badge

    private var harvardBadge: some View {
        Image(.harvardLogo)
            .resizable()
            .scaledToFit()
            .frame(height: 36)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        OnboardingContinueButton(action: viewModel.advance)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 30)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                value: showButton
            )
    }

    // MARK: - Animation sequence

    @MainActor
    private func runAnimationSequence() async {
        guard !reduceMotion else {
            numberOpacity = 1; numberScale = 1
            showBody = true; showBadge = true; showButton = true
            return
        }

        // 1. Spring the big number in after a short pause
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.spring(duration: 0.6, bounce: 0.6)) {
            numberOpacity = 1
            numberScale   = 1
        }

        // 2. Body text after number lands
        try? await Task.sleep(for: .milliseconds(500))
        showBody = true

        // 3. Harvard badge
        try? await Task.sleep(for: .milliseconds(220))
        showBadge = true

        // 4. Continue button
        try? await Task.sleep(for: .milliseconds(220))
        showButton = true
    }
}

#Preview {
    OnboardingStatisticsStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
