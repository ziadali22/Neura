import SwiftUI

struct GrowthEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("measure")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(L10n.Growth.emptyTitle)
                    .font(.headingS)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.Growth.emptySubtitle)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 24)

            Button(action: onAdd) {
                Text(L10n.Growth.add)
                    .font(.headingXS)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.surfaceDark)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GrowthEmptyState(onAdd: {})
        .background(Color.backgroundPrimary)
}
