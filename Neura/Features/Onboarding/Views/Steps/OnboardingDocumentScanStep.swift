import SwiftUI

struct OnboardingDocumentScanStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var buttonEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation — hidden when reduce motion is on, replaced by a static icon
            if reduceMotion {
                staticIllustration
            } else {
                OnboardingScanningAnimation(onComplete: { buttonEnabled = true })
                    .padding(.horizontal, 48)
                    .opacity(appeared ? 1 : 0)
            }

            Spacer()

            // Text
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Onboarding.DocumentScan.title)
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Onboarding.DocumentScan.subtitle)
                    .font(.bodyL)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            OnboardingContinueButton(action: viewModel.advance, isEnabled: buttonEnabled)
        }
        .task {
            if reduceMotion { buttonEnabled = true }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Reduce-motion fallback

    private var staticIllustration: some View {
        VStack(spacing: 16) {
            ForEach([Column.scan, Column.organize, Column.share], id: \.id) { column in
                HStack(spacing: 12) {
                    Image(systemName: column.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(column.accentColor)
                        .frame(width: 36, height: 36)
                        .background(column.accentColor.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(column.title)
                            .font(.headingXS)
                            .foregroundStyle(Color.textPrimary)
                        Text(column.subtitle)
                            .font(.bodyS)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Three steps: Scan your documents, Organize by category, Share with your doctor")
    }

}

#Preview {
    OnboardingDocumentScanStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
