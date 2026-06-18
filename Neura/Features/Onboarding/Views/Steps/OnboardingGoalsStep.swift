import SwiftUI

struct OnboardingGoalsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Onboarding.Goals.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text(L10n.Onboarding.Goals.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(UserGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                            GoalCard(
                                goal: goal,
                                isSelected: viewModel.state.goals.contains(goal)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    if viewModel.state.goals.contains(goal) {
                                        viewModel.state.goals.remove(goal)
                                    } else {
                                        viewModel.state.goals.insert(goal)
                                    }
                                }
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.85)
                                    .delay(Double(index) * 0.09),
                                value: appeared
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
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

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: UserGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.white.opacity(0.18) : Color.accent.opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: goal.icon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Color.accent)
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.accent)
                            .accessibilityHidden(true)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }

                Text(goal.rawValue)
                    .font(.headingXS)
                    .foregroundStyle(isSelected ? .white : Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
            .background(isSelected ? Color.black : Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.accent.opacity(0.35) : Color.stroke.opacity(0.7),
                        lineWidth: 1
                    )
            }
            // Layered shadows: tight contact shadow + diffuse ambient
            .shadow(
                color: isSelected ? .black.opacity(0.14) : .black.opacity(0.04),
                radius: isSelected ? 3 : 2,
                x: 0, y: isSelected ? 2 : 1
            )
            .shadow(
                color: isSelected ? Color.accent.opacity(0.22) : .black.opacity(0.07),
                radius: isSelected ? 20 : 14,
                x: 0, y: isSelected ? 8 : 5
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(minHeight: 120)
    }
}

#Preview { OnboardingGoalsStep(viewModel: OnboardingViewModel()) }
