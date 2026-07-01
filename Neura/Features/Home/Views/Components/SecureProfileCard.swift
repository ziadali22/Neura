import SwiftUI

struct SecureProfileCard: View {
    let name: String
    let location: String
    let background: CardBackground
    var onShareTap: (() -> Void)?
    var onCustomizeTap: (() -> Void)?
    var onTap: (() -> Void)?

    /// Card height scales with the device so smaller iPhones get a shorter
    /// card while larger phones keep the full presence. Clamped 360–450pt.
    private var cardHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return max(360, min(450, screenHeight * 0.5))
    }

    var body: some View {
        ZStack {
            CardBackgroundView(background: background, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .overlay {
                    VStack {
                        topBar
                            .padding(.horizontal, 35)
                            .padding(.top, 24)

                        Spacer()

                        VStack(spacing: 8) {
                            Text(name.uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)

                            locationView
                        }
                        .padding(.bottom, 24)
                        .padding(.horizontal, 35)
                    }
                }
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 15,
                    x: 0,
                    y: 10
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 40))
        .onTapGesture { onTap?() }
        .accessibilityLabel("Health profile card")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap?() }
    }
}

// MARK: - Subviews

private extension SecureProfileCard {
    var topBar: some View {
        HStack {
            Label("ENCRYPTED & SECURE", systemImage: "checkmark.shield")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 6) {
                Button("Customize card", systemImage: "paintbrush.fill") { onCustomizeTap?() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 35, height: 35)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())

                Button("Share health profile", systemImage: "square.and.arrow.up") { onShareTap?() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 35, height: 35)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }

    var locationView: some View {
        Label(location, systemImage: "house")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
    }
}

#Preview {
    SecureProfileCard(
        name: "Ziad Ali Khalil",
        location: "Egypt, Cairo",
        background: .default
    )
}
