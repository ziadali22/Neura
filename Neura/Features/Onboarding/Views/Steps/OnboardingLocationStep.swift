import SwiftUI

struct OnboardingLocationStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
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
                        Text("Where are\nyou based?")
                            .font(.displayL)
                            .foregroundStyle(Color.textPrimary)

                        Text("Your location appears on your health profile card.")
                            .font(.bodyL)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Fields
                    VStack(spacing: 16) {
                        // City
                        VStack(alignment: .leading, spacing: 8) {
                            Text("City")
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)

                            HStack(spacing: 12) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)

                                TextField("e.g. Lasi", text: $viewModel.state.city)
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
                            Text("Country")
                                .font(.headingXS)
                                .foregroundStyle(Color.textPrimary)

                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)

                                TextField("e.g. Romania", text: $viewModel.state.country)
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

            OnboardingContinueButton(action: viewModel.advance)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

}

#Preview {
    OnboardingLocationStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
