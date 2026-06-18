import SwiftUI

struct OnboardingLocationStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var locationDetector = LocationDetector()
    @State private var appeared = false
    @FocusState private var focusedField: Field?

    private enum Field { case city, country }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Illustration
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.accent.opacity(0.08))
                                .frame(width: 120, height: 120)
                            Circle()
                                .fill(Color.accent.opacity(0.05))
                                .frame(width: 160, height: 160)
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.accent)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Onboarding.Location.title)
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)

                        Text(L10n.Onboarding.Location.subtitle)
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Detect location button
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            focusedField = nil
                            locationDetector.detect { city, country in
                                viewModel.state.city = city
                                viewModel.state.country = country
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if locationDetector.isDetecting {
                                    ProgressView()
                                        .tint(Color.accent)
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.accent)
                                }
                                Text(locationDetector.isDetecting ? "Detecting location…" : "Detect my location")
                                    .font(.bodyL)
                                    .foregroundStyle(Color.accent)
                                Spacer()
                                if !locationDetector.isDetecting {
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textTertiary)
                                }
                            }
                            .padding(16)
                            .background(Color.accent.opacity(0.07))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(locationDetector.isDetecting)

                        if let error = locationDetector.errorMessage {
                            Text(error)
                                .font(.captionS)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                    }

                    // Fields
                    VStack(spacing: 16) {
                        // City
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.Onboarding.Location.city)
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)

                            HStack(spacing: 12) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)

                                TextField(L10n.Onboarding.Location.cityPlaceholder, text: $viewModel.state.city)
                                    .font(.bodyL)
                                    .focused($focusedField, equals: .city)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .country }
                            }
                            .padding(16)
                            .background(Color.surfaceWhite)
                            .clipShape(.rect(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }

                        // Country
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.Onboarding.Location.country)
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)

                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)

                                TextField(L10n.Onboarding.Location.countryPlaceholder, text: $viewModel.state.country)
                                    .font(.bodyL)
                                    .focused($focusedField, equals: .country)
                                    .submitLabel(.done)
                                    .onSubmit { focusedField = nil }
                            }
                            .padding(16)
                            .background(Color.surfaceWhite)
                            .clipShape(.rect(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
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

            OnboardingContinueButton(action: viewModel.advance, isEnabled: canContinue)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var canContinue: Bool {
        !viewModel.state.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.state.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

}

#Preview {
    OnboardingLocationStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
