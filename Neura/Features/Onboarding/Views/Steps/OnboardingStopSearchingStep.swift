import SwiftUI

struct OnboardingStopSearchingStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showImage = false
    @State private var showText = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            imageSection

            Spacer()

            textSection

            continueButton
        }
        .task { await runAnimationSequence() }
    }

    // MARK: - Sections

    private var imageSection: some View {
        Image("canYou")
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
            .padding(.horizontal, 32)
            .scaleEffect(showImage ? 1 : 0.88)
            .opacity(showImage ? 1 : 0)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.78),
                value: showImage
            )
    }

    private var textSection: some View {
        Text("Stop searching for\nyour medical records")
            .font(.displayL)
            .fontWeight(.bold)
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 18)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.85),
                value: showText
            )
    }

    private var continueButton: some View {
        OnboardingContinueButton(action: viewModel.advance)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 30)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.85),
                value: showButton
            )
    }

    // MARK: - Animation

    @MainActor
    private func runAnimationSequence() async {
        guard !reduceMotion else {
            showImage = true; showText = true; showButton = true
            return
        }
        try? await Task.sleep(for: .milliseconds(80))
        showImage = true
        try? await Task.sleep(for: .milliseconds(300))
        showText = true
        try? await Task.sleep(for: .milliseconds(200))
        showButton = true
    }
}

#Preview {
    OnboardingStopSearchingStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
