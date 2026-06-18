import SwiftUI

struct OnboardingCardStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var cardAppear = false
    @State private var actionsAppear = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(L10n.Onboarding.EmergencyCard.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(L10n.Onboarding.EmergencyCard.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Full card display
                    fullEmergencyCard
                        .scaleEffect(cardAppear ? 1 : 0.9)
                        .opacity(cardAppear ? 1 : 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)

            OnboardingContinueButton(action: viewModel.advance)
                .opacity(actionsAppear ? 1 : 0)
                .offset(y: actionsAppear ? 0 : 16)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { cardAppear = true }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { actionsAppear = true }
        }
    }

    private var fullEmergencyCard: some View {
        let state = viewModel.state
        return VStack(spacing: 0) {
            // Header
            ZStack {
                LinearGradient(colors: [Color(hex: "E8392E"), Color(hex: "C41E14")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Emergency.inCaseOf).font(.labelM).fontWeight(.bold).tracking(2)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(L10n.Emergency.emergency).font(.system(size: 26, weight: .heavy)).tracking(1)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "staroflife.fill").font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.18))
                }
                .padding(20)
            }
            .frame(height: 92)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 0,
                                              bottomTrailingRadius: 0, topTrailingRadius: 22))

            // Body
            VStack(spacing: 0) {
                cardBodyRow("person.fill", L10n.Onboarding.EmergencyCard.nameLabel, state.name.isEmpty ? L10n.Onboarding.EmergencyCard.notSet : state.name)
                Divider().padding(.leading, 56)
                cardBodyRow("phone.fill", L10n.Onboarding.EmergencyCard.emergencyContactLabel,
                            state.emergencyContactPhone.isEmpty ? L10n.Onboarding.EmergencyCard.notSet : state.emergencyContactPhone)
                Divider().padding(.leading, 56)
                cardBodyRow("drop.fill", L10n.Onboarding.EmergencyCard.bloodTypeLabel, state.bloodType?.rawValue ?? L10n.Onboarding.EmergencyCard.notSet)
                Divider().padding(.leading, 56)

                // Neura branding footer
                HStack(spacing: 8) {
                    Circle().fill(Color.accent).frame(width: 5, height: 5)
                    Text(L10n.Onboarding.EmergencyCard.poweredBy).font(.captionS).foregroundStyle(Color.textTertiary)
                    Text(L10n.Common.neura).font(.captionS).fontWeight(.bold).foregroundStyle(Color.accent)
                }
                .padding(.vertical, 12)
            }
            .background(.white)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 22,
                                              bottomTrailingRadius: 22, topTrailingRadius: 0))
        }
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 7)
    }

    private func cardBodyRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "E8392E").opacity(0.08))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "E8392E"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.captionS)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "CC1A10"))
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text(value)
                    .font(.bodyS)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview { OnboardingCardStep(viewModel: OnboardingViewModel()) }
