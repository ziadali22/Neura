import SwiftUI

struct OnboardingProfileCardIntroStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation state

    @State private var cardOpacity: CGFloat = 0
    @State private var cardScale: CGFloat = 0.85
    @State private var showTitle: Bool = false
    @State private var showSubtitle: Bool = false
    @State private var showButton: Bool = false

    // MARK: - Derived display values

    private var displayName: String {
        let n = viewModel.state.name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "YOUR NAME" : n.uppercased()
    }

    private var displayLocation: String {
        let city    = viewModel.state.city.trimmingCharacters(in: .whitespaces)
        let country = viewModel.state.country.trimmingCharacters(in: .whitespaces)
        switch (city.isEmpty, country.isEmpty) {
        case (false, false): return "\(city), \(country)"
        case (false, true):  return city
        case (true, false):  return country
        case (true, true):   return L10n.Onboarding.ProfileCard.yourCity
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero: health card springs in
            SecureProfileCard(
                name: displayName,
                location: displayLocation,
                background: CardBackground.imageBackgrounds.first ?? .default
            )
            .allowsHitTesting(false)
            .padding(.horizontal, 32)
            .opacity(cardOpacity)
            .scaleEffect(cardScale)

            Spacer(minLength: 36)

            // Text block
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Onboarding.ProfileCardIntro.title)
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                        value: showTitle
                    )

                Text(L10n.Onboarding.ProfileCardIntro.subtitle)
                    .font(.bodyL)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                        value: showSubtitle
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Continue button
            OnboardingContinueButton(action: viewModel.advance)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 24)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                    value: showButton
                )
        }
        .task { await runAnimationSequence() }
    }

    // MARK: - Animation sequence

    @MainActor
    private func runAnimationSequence() async {
        guard !reduceMotion else {
            cardOpacity = 1; cardScale = 1
            showTitle = true; showSubtitle = true; showButton = true
            return
        }

        // Card springs in
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
            cardOpacity = 1
            cardScale   = 1
        }

        // Title
        try? await Task.sleep(for: .milliseconds(400))
        showTitle = true

        // Subtitle
        try? await Task.sleep(for: .milliseconds(180))
        showSubtitle = true

        // Button
        try? await Task.sleep(for: .milliseconds(180))
        showButton = true
    }
}

#Preview {
    OnboardingProfileCardIntroStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
