import SwiftUI

struct OnboardingProfileStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var selectedDay: Int = 1
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2000
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Onboarding.Profile.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)
                        Text(L10n.Onboarding.Profile.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(spacing: 16) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.Onboarding.Profile.fullName)
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)
                                TextField(L10n.Onboarding.Profile.fullNamePlaceholder, text: $viewModel.state.name)
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
                            Text(L10n.Onboarding.Profile.dateOfBirth)
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)
                            HStack(spacing: 0) {
                                Picker(L10n.Onboarding.Profile.day, selection: $selectedDay) {
                                    ForEach(1...31, id: \.self) { day in
                                        Text("\(day)").tag(day)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)

                                Picker(L10n.Onboarding.Profile.month, selection: $selectedMonth) {
                                    ForEach(1...12, id: \.self) { month in
                                        Text(Calendar.current.shortMonthSymbols[month - 1]).tag(month)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)

                                Picker(L10n.Onboarding.Profile.year, selection: $selectedYear) {
                                    ForEach(1900...currentYear, id: \.self) { year in
                                        Text(String(year)).tag(year)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 150)
                            .onChange(of: selectedDay) { _, _ in updateDate() }
                            .onChange(of: selectedMonth) { _, _ in updateDate() }
                            .onChange(of: selectedYear) { _, _ in updateDate() }
                            .background(Color.surfaceWhite)
                            .clipShape(.rect(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }

                        // Gender
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text("Gender")
//                                .font(.headingXS)
//                                .foregroundStyle(Color.textPrimary)
//                            HStack(spacing: 8) {
//                                ForEach(ProfileGender.allCases) { gender in
//                                    genderPill(gender)
//                                }
//                            }
//                        }
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

            OnboardingContinueButton(action: viewModel.advance, isEnabled: canContinue)
        }
        .task {
            updateDate()
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

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private func updateDate() {
        var components = DateComponents()
        components.day = selectedDay
        components.month = selectedMonth
        components.year = selectedYear
        viewModel.state.dateOfBirth = Calendar.current.date(from: components)
    }

    private var canContinue: Bool {
        !viewModel.state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

}

#Preview { OnboardingProfileStep(viewModel: OnboardingViewModel()) }
