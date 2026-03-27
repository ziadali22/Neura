import SwiftUI

struct SecureProfileCard: View {
    let name: String
    let location: String
    let background: CardBackground
    var onShareTap: (() -> Void)?
    var onCustomizeTap: (() -> Void)?
    var onTap: (() -> Void)?

    @State private var dragAmount = CGSize.zero

    var body: some View {
        ZStack {
            CardBackgroundView(background: background, height: 450)
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
                    x: -dragAmount.width / 10,
                    y: 10 - dragAmount.height / 10
                )
        }
        .rotation3DEffect(
            .degrees(-Double(dragAmount.width) / 15),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(dragAmount.height) / 15),
            axis: (x: 1, y: 0, z: 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 40))
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring()) {
                        dragAmount = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragAmount = .zero
                    }
                }
        )
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
