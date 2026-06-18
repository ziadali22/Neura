import SwiftUI

struct OnboardingProfileStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var appeared = false
    @State private var showDatePicker = false
    @State private var selectedDay = 1
    @State private var selectedMonth = 1
    @State private var selectedYear = 2000
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
                        nameField
                        dateOfBirthField
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

            OnboardingContinueButton(action: viewModel.advance)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    // MARK: - Name

    // Optional. Pre-filled from Sign in with Apple/Google when the provider supplies it, so
    // users are never required to re-enter it (App Review 4 / Sign in with Apple).
    private var nameField: some View {
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
    }

    // MARK: - Date of Birth

    // Optional (App Review 5.1.1(v)). Collapsed by default so nothing is collected unless the
    // user explicitly taps to add it — they can always continue without providing it, and can
    // clear it afterwards.
    private var dateOfBirthField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L10n.Onboarding.Profile.dateOfBirth)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)
                Text(L10n.Common.optional)
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                if showDatePicker {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showDatePicker = false
                            viewModel.state.dateOfBirth = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            if showDatePicker {
                HStack(spacing: 0) {
                    Picker(L10n.Onboarding.Profile.day, selection: $selectedDay) {
                        ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker(L10n.Onboarding.Profile.month, selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { Text(Calendar.current.shortMonthSymbols[$0 - 1]).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker(L10n.Onboarding.Profile.year, selection: $selectedYear) {
                        ForEach(1900...currentYear, id: \.self) { Text(String($0)).tag($0) }
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
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showDatePicker = true
                    }
                    updateDate()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textTertiary)
                        Text(L10n.HealthProfile.addDate)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(16)
                    .background(Color.surfaceWhite)
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
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
}

#Preview { OnboardingProfileStep(viewModel: OnboardingViewModel()) }
