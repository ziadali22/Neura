import SwiftUI

struct OnboardingProfileStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var showDatePicker = false
    @State private var localDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create your\nhealth profile")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text("Just the basics — you can add more later.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(spacing: 16) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)
                                TextField("Your full name", text: $viewModel.state.name)
                                    .font(.bodyL)
                                    .focused($nameFocused)
                                    .submitLabel(.done)
                                    .onSubmit { nameFocused = false }
                            }
                            .padding(16)
                            .background(Color.surfaceWhite)
                            .clipShape(.rect(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }

                        // Date of Birth
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth")
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)
                            Button {
                                nameFocused = false
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showDatePicker.toggle()
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.state.dateOfBirth != nil
                                         ? localDate.formatted(.dateTime.day().month(.wide).year())
                                         : "Select date")
                                        .font(.bodyL)
                                        .foregroundStyle(viewModel.state.dateOfBirth != nil ? Color.textPrimary : Color.textTertiary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textTertiary)
                                        .rotationEffect(.degrees(showDatePicker ? 90 : 0))
                                }
                                .padding(16)
                                .background(Color.surfaceWhite)
                                .clipShape(.rect(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }
                            if showDatePicker {
                                DatePicker("", selection: $localDate, in: ...Date(), displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(.black)
                                    .labelsHidden()
                                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                                    .onChange(of: localDate) { _, date in
                                        viewModel.state.dateOfBirth = date
                                    }
                            }
                        }

                        // Gender
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)
                            HStack(spacing: 8) {
                                ForEach(ProfileGender.allCases) { gender in
                                    genderPill(gender)
                                }
                            }
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
            .scrollDismissesKeyboard(.immediately)

            continueButton
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func genderPill(_ gender: ProfileGender) -> some View {
        let selected = viewModel.state.gender == gender
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.state.gender = gender
            }
        } label: {
            Text(gender.rawValue)
                .font(.buttonM)
                .foregroundStyle(selected ? .white : Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.black : Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var canContinue: Bool {
        !viewModel.state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var continueButton: some View {
        Button(action: viewModel.advance) {
            Text("Continue")
                .font(.buttonL)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canContinue ? Color.black : Color.textTertiary)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: canContinue ? .black.opacity(0.15) : .clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canContinue)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

#Preview { OnboardingProfileStep(viewModel: OnboardingViewModel()) }
