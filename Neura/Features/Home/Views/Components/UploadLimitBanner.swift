import SwiftUI

struct UploadLimitBanner: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onTap: () -> Void

    /// Before the limit is reached: "X/3 free Documents Uploads left".
    /// Once reached: an upsell prompting the user to remove the limit.
    private var title: String {
        subscriptionManager.canUpload
            ? L10n.Home.UploadLimit.remaining(subscriptionManager.remainingText)
            : L10n.Home.UploadLimit.reachedTitle
    }

    private var subtitle: String {
        subscriptionManager.canUpload
            ? L10n.Home.UploadLimit.upgrade
            : L10n.Home.UploadLimit.reachedSubtitle
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image("premiumIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(subtitle)
                        .font(.captionS)
                        .foregroundColor(Color.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.forward")
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
