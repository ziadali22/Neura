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
                            Text("Your health\nhistory")
                                .font(.displayL)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("Optional")
                                .font(.labelM)
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.surfaceWhite)
                                .clipShape(Capsule())
                                .padding(.top, 4)
                        }
                        Text("Add a few entries to get started — you can always edit later.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(spacing: 16) {
                        medicalField("pill.fill", "Medications",
                                    "e.g. Vitamin D, Aspirin (separate with commas)",
                                    text: $viewModel.state.medications, field: .medications,
                                    next: .allergies)

                        medicalField("exclamationmark.triangle.fill", "Allergies",
                                    "e.g. Peanuts, Penicillin",
                                    text: $viewModel.state.allergies, field: .allergies,
                                    next: .conditions)

                        medicalField("heart.text.clipboard", "Conditions",
                                    "e.g. Hypertension, Diabetes",
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

            // Actions
            VStack(spacing: 12) {
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

                Button("Skip for now") { viewModel.advance() }
                    .font(.bodyL)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accent)
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
