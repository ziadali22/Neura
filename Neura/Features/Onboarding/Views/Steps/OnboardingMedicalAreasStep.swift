import SwiftUI

struct OnboardingMedicalAreasStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which medical areas\nare relevant to you?")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)

                        Text("Select a few to organize your medical records. You can change this anytime.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Area list
                    VStack(spacing: 8) {
                        ForEach(MedicalArea.allCases) { area in
                            areaRow(area)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)

            OnboardingContinueButton(action: viewModel.advance)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Row

    private func areaRow(_ area: MedicalArea) -> some View {
        let selected = viewModel.state.medicalAreas.contains(area)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if selected {
                    viewModel.state.medicalAreas.remove(area)
                } else {
                    viewModel.state.medicalAreas.insert(area)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: area.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 24, alignment: .center)

                Text(area.rawValue)
                    .font(.bodyL)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.textPrimary : Color.clear)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.textPrimary : Color.stroke, lineWidth: 1.5)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area.rawValue)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isToggle)
    }

}

#Preview {
    OnboardingMedicalAreasStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
