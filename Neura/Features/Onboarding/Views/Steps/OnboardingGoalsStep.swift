import SwiftUI

struct OnboardingGoalsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What will you\nuse Neura for?")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text("Select all that apply")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(UserGoal.allCases) { goal in
                            goalCard(goal)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)

            continueButton
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func goalCard(_ goal: UserGoal) -> some View {
        let selected = viewModel.state.goals.contains(goal)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if selected {
                    viewModel.state.goals.remove(goal)
                } else {
                    viewModel.state.goals.insert(goal)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? Color.white.opacity(0.25) : Color.accent.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: goal.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selected ? .white : Color.accent)
                }
                Text(goal.rawValue)
                    .font(.headingXS)
                    .foregroundStyle(selected ? .white : Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .background(selected ? Color.black : Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: selected ? Color.accent.opacity(0.25) : .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(height: 110)
    }

    private var continueButton: some View {
        Button(action: viewModel.advance) {
            Text("Continue")
                .font(.buttonL)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

#Preview { OnboardingGoalsStep(viewModel: OnboardingViewModel()) }
