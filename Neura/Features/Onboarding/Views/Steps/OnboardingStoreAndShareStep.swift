import SwiftUI

struct OnboardingStoreAndShareStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Question data

    private struct QuestionPill: Identifiable {
        let id = UUID()
        let text: String
        let rotation: Double
    }

    private let questions: [QuestionPill] = [
        .init(text: L10n.Onboarding.StoreAndShare.q1, rotation: -2.5),
        .init(text: L10n.Onboarding.StoreAndShare.q2, rotation:  1.5),
        .init(text: L10n.Onboarding.StoreAndShare.q3, rotation: -1.0),
        .init(text: L10n.Onboarding.StoreAndShare.q4, rotation:  0.5),
        .init(text: L10n.Onboarding.StoreAndShare.q5, rotation:  2.0),
    ]

    // MARK: - Animation state

    @State private var visiblePillCount: Int = 0
    @State private var showText: Bool = false
    @State private var showButton: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            pillsSection

            Spacer()

            textSection

            continueButton
        }
        .task { await runAnimationSequence() }
    }

    // MARK: - Sections

    private var pillsSection: some View {
        VStack(spacing: 12) {
            ForEach(questions.indices, id: \.self) { index in
                makePill(questions[index])
                    .opacity(index < visiblePillCount ? 1 : 0)
                    .offset(y: index < visiblePillCount ? 0 : 50)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: visiblePillCount
                    )
            }
        }
        .padding(.horizontal, 24)
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Onboarding.StoreAndShare.title)
                .font(.displayL)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)

            Text(L10n.Onboarding.StoreAndShare.subtitle)
                .font(.bodyL)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .opacity(showText ? 1 : 0)
        .offset(y: showText ? 0 : 20)
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.85),
            value: showText
        )
    }

    private var continueButton: some View {
        OnboardingContinueButton(action: viewModel.advance)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 30)
            .animation(
                reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.85),
                value: showButton
            )
    }

    // MARK: - Pill builder

    private func makePill(_ pill: QuestionPill) -> some View {
        Text(pill.text)
            .font(.bodyL)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .rotationEffect(.degrees(pill.rotation))
    }

    // MARK: - Animation sequence

    @MainActor
    private func runAnimationSequence() async {
        guard !reduceMotion else {
            visiblePillCount = questions.count
            showText = true
            showButton = true
            return
        }

        // Initial pause before first pill
        try? await Task.sleep(for: .milliseconds(100))

        // Stagger each pill in
        for i in 0..<questions.count {
            if i > 0 { try? await Task.sleep(for: .milliseconds(130)) }
            visiblePillCount = i + 1
        }

        // Text block appears after all pills land
        try? await Task.sleep(for: .milliseconds(320))
        showText = true

        // Button slides up shortly after text
        try? await Task.sleep(for: .milliseconds(200))
        showButton = true
    }
}

#Preview {
    OnboardingStoreAndShareStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
