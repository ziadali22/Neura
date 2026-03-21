import SwiftUI

struct OnboardingEmergencyStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, phone }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Set up your\nemergency card")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text("First responders can see this in an emergency.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Mini card preview
                    MiniEmergencyCard(state: viewModel.state)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(appeared ? 1 : 0)

                    // Form
                    VStack(spacing: 16) {
                        // Contact name
                        formField("Emergency Contact Name", placeholder: "e.g. Sarah Johnson",
                                  text: $viewModel.state.emergencyContactName, field: .name)

                        // Contact phone
                        formField("Phone Number", placeholder: "+1 555 000 0000",
                                  text: $viewModel.state.emergencyContactPhone, field: .phone)
                            .keyboardType(.phonePad)

                        // Blood type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blood Type (optional)")
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(BloodType.allCases) { type in
                                        bloodTypeChip(type)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                            .scrollIndicators(.hidden)
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
            .onTapGesture { focusedField = nil }

            continueButton
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func formField(_ label: String, placeholder: String,
                           text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)
            TextField(placeholder, text: text)
                .font(.bodyL)
                .focused($focusedField, equals: field)
                .padding(16)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func bloodTypeChip(_ type: BloodType) -> some View {
        let selected = viewModel.state.bloodType == type
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.state.bloodType = selected ? nil : type
            }
        } label: {
            Text(type.rawValue)
                .font(.buttonM)
                .foregroundStyle(selected ? .white : Color.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(selected ? Color.black : Color.surfaceWhite)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var continueButton: some View {
        VStack(spacing: 10) {
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
                .font(.bodyS)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Mini Emergency Card

private struct MiniEmergencyCard: View {
    let state: OnboardingState

    var body: some View {
        VStack(spacing: 0) {
            // Red header
            ZStack {
                LinearGradient(colors: [Color(hex: "E8392E"), Color(hex: "C41E14")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IN CASE OF")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2.5)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("EMERGENCY")
                            .font(.system(size: 20, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.18))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .frame(height: 72)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 0,
                                              bottomTrailingRadius: 0, topTrailingRadius: 18))

            // White body
            VStack(spacing: 0) {
                cardRow("person.fill", state.name.isEmpty ? "Your name" : state.name,
                        isPlaceholder: state.name.isEmpty)
                Divider().padding(.leading, 44)
                cardRow("phone.fill",
                        state.emergencyContactPhone.isEmpty ? "Emergency contact" : state.emergencyContactPhone,
                        isPlaceholder: state.emergencyContactPhone.isEmpty)
                Divider().padding(.leading, 44)
                cardRow("drop.fill", state.bloodType?.rawValue ?? "Blood type",
                        isPlaceholder: state.bloodType == nil)
            }
            .background(.white)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 18,
                                              bottomTrailingRadius: 18, topTrailingRadius: 0))
        }
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private func cardRow(_ icon: String, _ text: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "E8392E").opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "E8392E"))
            }
            Text(text)
                .font(.system(size: 14, weight: isPlaceholder ? .regular : .medium))
                .foregroundStyle(isPlaceholder ? Color.textTertiary : Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview { OnboardingEmergencyStep(viewModel: OnboardingViewModel()) }
