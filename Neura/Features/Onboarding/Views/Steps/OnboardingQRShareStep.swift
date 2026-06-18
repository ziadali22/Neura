import SwiftUI
import Lottie

struct OnboardingQRShareStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation state

    @State private var mediaAppeared = false
    @State private var showTitle     = false
    @State private var showSubtitle  = false
    @State private var showButton    = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            mediaContainer
                .scaleEffect(mediaAppeared ? 1 : 0.88)
                .opacity(mediaAppeared ? 1 : 0)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.82),
                    value: mediaAppeared
                )
                .padding(.top, 24)

            Spacer(minLength: 16)

            textSection
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            continueButton
        }
        .task { await setupAndAnimate() }
    }

    // MARK: - Media

    private var mediaContainer: some View {
        LottieView(name: "qrShare", loopMode: .loop)
            .containerRelativeFrame(.vertical) { h, _ in h * 0.60 }
            .accessibilityLabel(L10n.Onboarding.QRShare.mediaAccessibility)
    }

    // MARK: - Text section

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Onboarding.QRShare.title)
                .font(.displayL)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 16)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.85),
                    value: showTitle
                )

            Text(L10n.Onboarding.QRShare.subtitle)
                .font(.bodyL)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showSubtitle ? 1 : 0)
                .offset(y: showSubtitle ? 0 : 12)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.85),
                    value: showSubtitle
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Setup & animation

    @MainActor
    private func setupAndAnimate() async {
        guard !reduceMotion else {
            mediaAppeared = true
            showTitle     = true
            showSubtitle  = true
            showButton    = true
            return
        }

        try? await Task.sleep(for: .milliseconds(150))
        mediaAppeared = true

        try? await Task.sleep(for: .milliseconds(400))
        showTitle = true

        try? await Task.sleep(for: .milliseconds(180))
        showSubtitle = true

        try? await Task.sleep(for: .milliseconds(220))
        showButton = true
    }

}

#Preview {
    OnboardingQRShareStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
