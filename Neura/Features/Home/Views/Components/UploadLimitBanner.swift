import SwiftUI

struct UploadLimitBanner: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image("premiumIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Home.UploadLimit.remaining(subscriptionManager.limitText))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(L10n.Home.UploadLimit.upgrade)
                        .font(.captionS)
                        .foregroundColor(Color.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    UploadLimitBanner(
        subscriptionManager: .shared,
        onTap: {}
    )
    .padding()
    .background(Color.backgroundPrimary)
}
