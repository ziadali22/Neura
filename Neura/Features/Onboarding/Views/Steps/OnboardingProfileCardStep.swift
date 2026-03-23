import SwiftUI

struct OnboardingProfileCardStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var headerAppeared = false
    @State private var carouselAppeared = false
    @State private var buttonAppeared = false
    @State private var scrolledID: String? = CardBackground.imageBackgrounds.first?.id

    private let presets = CardBackground.imageBackgrounds

    // MARK: - Derived State

    private var selectedIndex: Int {
        guard let id = scrolledID else { return 0 }
        return presets.firstIndex(where: { $0.id == id }) ?? 0
    }

    private var displayName: String {
        let n = viewModel.state.name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "YOUR NAME" : n.uppercased()
    }

    private var displayLocation: String {
        let city = viewModel.state.city.trimmingCharacters(in: .whitespaces)
        let country = viewModel.state.country.trimmingCharacters(in: .whitespaces)
        switch (city.isEmpty, country.isEmpty) {
        case (false, false): return "\(city), \(country)"
        case (false, true):  return city
        case (true, false):  return country
        case (true, true):   return "Your City"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            carousel
            dots
            Spacer(minLength: 24)
            useButton
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { headerAppeared = true }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { carouselAppeared = true }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { buttonAppeared = true }
        }
    }
}

// MARK: - Subviews

private extension OnboardingProfileCardStep {
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your profile card")
                .font(.displayL)
                .foregroundStyle(Color.textPrimary)
            Text("This is how your profile appears on your home screen. Only you can see it — never shared with doctors.")
                .font(.bodyL)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 16)
    }

    var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
                ForEach(presets) { bg in
                    SecureProfileCard(
                        name: displayName,
                        location: displayLocation,
                        background: bg
                    )
                    .allowsHitTesting(false)
                    .containerRelativeFrame(.horizontal) { width, _ in width - 80 }
                    .scrollTransition { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.88)
                            .opacity(phase.isIdentity ? 1 : 0.65)
                    }
                    .id(bg.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 40)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledID)
        .opacity(carouselAppeared ? 1 : 0)
        .offset(y: carouselAppeared ? 0 : 24)
    }

    var dots: some View {
        HStack(spacing: 8) {
            ForEach(presets.indices, id: \.self) { i in
                Circle()
                    .fill(i == selectedIndex ? Color.textPrimary : Color.stroke)
                    .frame(
                        width: i == selectedIndex ? 8 : 6,
                        height: i == selectedIndex ? 8 : 6
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedIndex)
            }
        }
        .padding(.top, 16)
        .opacity(carouselAppeared ? 1 : 0)
    }

    var useButton: some View {
        Button {
            viewModel.state.cardBackground = presets[selectedIndex]
            viewModel.advance()
        } label: {
            Text("Use this card")
                .font(.buttonL)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .opacity(buttonAppeared ? 1 : 0)
        .offset(y: buttonAppeared ? 0 : 16)
    }
}

#Preview {
    OnboardingProfileCardStep(viewModel: OnboardingViewModel())
}
