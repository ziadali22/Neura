import SwiftUI

struct OnboardingDocumentsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Spacer()
                        DocStackIllustration(appeared: appeared, reduceMotion: reduceMotion)
                        Spacer()
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Onboarding.Documents.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)

                        Text(L10n.Onboarding.Documents.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        DocFeatureRow(
                            icon: "doc.viewfinder",
                            title: L10n.Onboarding.Documents.scanTitle,
                            description: L10n.Onboarding.Documents.scanSubtitle
                        )
                        Divider().padding(.leading, 52)
                        DocFeatureRow(
                            icon: "folder.badge.questionmark",
                            title: L10n.Onboarding.Documents.categorizeTitle,
                            description: L10n.Onboarding.Documents.categorizeSubtitle
                        )
                        Divider().padding(.leading, 52)
                        DocFeatureRow(
                            icon: "qrcode",
                            title: L10n.Onboarding.Documents.qrTitle,
                            description: L10n.Onboarding.Documents.qrSubtitle
                        )
                    }
                    .background(Color.surfaceWhite)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.85),
                    value: appeared
                )
            }
            .scrollIndicators(.hidden)

            OnboardingContinueButton(action: viewModel.advance)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            appeared = true
        }
    }
}

// MARK: - DocStackIllustration

private struct DocStackIllustration: View {
    let appeared: Bool
    let reduceMotion: Bool

    private struct DocCard: Identifiable {
        let id: Int
        let icon: String
        let label: String
        let rotation: Double
        let xOffset: CGFloat
        let yOffset: CGFloat
    }

    private let cards: [DocCard] = [
        DocCard(id: 0, icon: "pills.circle.fill",    label: "Prescription",    rotation: -7, xOffset: -26, yOffset: 12),
        DocCard(id: 1, icon: "waveform.path.ecg",    label: "Lab Results",     rotation:  4, xOffset:  22, yOffset:  4),
        DocCard(id: 2, icon: "doc.text.fill",        label: "Medical Report",  rotation:  0, xOffset:   0, yOffset: -16),
    ]

    var body: some View {
        ZStack {
            ForEach(cards) { card in
                SingleDocCard(icon: card.icon, label: card.label)
                    .rotationEffect(.degrees(appeared ? card.rotation : 0))
                    .offset(
                        x: appeared ? card.xOffset : 0,
                        y: appeared ? card.yOffset : 0
                    )
                    .zIndex(Double(card.id))
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.75).delay(Double(card.id) * 0.07),
                        value: appeared
                    )
            }
        }
        .frame(height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Three stacked document cards: Prescription, Lab Results, Medical Report")
    }
}

// MARK: - SingleDocCard

private struct SingleDocCard: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.accent)
                .frame(width: 36, height: 36)
                .background(Color.accent.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))

            Text(label)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 230)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.09), radius: 14, x: 0, y: 5)
    }
}

// MARK: - DocFeatureRow

private struct DocFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.accent)
                .frame(width: 36, height: 36)
                .background(Color.accent.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                Text(description)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    OnboardingDocumentsStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
