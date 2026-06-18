import SwiftUI

struct OnboardingMedicalStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case medications, allergies, conditions }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(L10n.Onboarding.Medical.title)
                                .font(.displayL)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
//                            Text(L10n.Common.optional)
//                                .font(.labelM)
//                                .foregroundStyle(Color.textTertiary)
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 5)
//                                .background(Color.surfaceWhite)
//                                .clipShape(Capsule())
//                                .padding(.top, 4)
                        }
                        Text(L10n.Onboarding.Medical.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(spacing: 16) {
                        medicalField("pill.fill", L10n.Onboarding.Medical.medications,
                                    L10n.Onboarding.Medical.medicationsPlaceholder,
                                    text: $viewModel.state.medications, field: .medications,
                                    next: .allergies)

                        medicalField("exclamationmark.triangle.fill", L10n.Onboarding.Medical.allergies,
                                    L10n.Onboarding.Medical.allergiesPlaceholder,
                                    text: $viewModel.state.allergies, field: .allergies,
                                    next: .conditions)

                        medicalField("heart.text.clipboard", L10n.Onboarding.Medical.conditions,
                                    L10n.Onboarding.Medical.conditionsPlaceholder,
                                    text: $viewModel.state.conditions, field: .conditions,
                                    next: nil)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)
            .onTapGesture { focusedField = nil }

            OnboardingContinueButton(action: viewModel.advance, secondaryTitle: L10n.Common.skipForNow)
                .opacity(appeared ? 1 : 0)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func medicalField(_ icon: String, _ label: String, _ placeholder: String,
                              text: Binding<String>, field: Field, next: Field?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
//                Image(systemName: icon)
//                    .font(.system(size: 13))
//                    .foregroundStyle(Color.accent)
                Text(label)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
            }
            TextField(placeholder, text: text, axis: .vertical)
                .font(.bodyL)
                .focused($focusedField, equals: field)
                .lineLimit(2...)
                .submitLabel(next != nil ? .next : .done)
                .onSubmit { focusedField = next }
                .padding(16)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview { OnboardingMedicalStep(viewModel: OnboardingViewModel()) }
