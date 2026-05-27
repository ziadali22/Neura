import SwiftUI

struct NeuraProCard: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        if subscriptionManager.isPro {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.Profile.Pro.title)
                        .font(.headingL)
                        .foregroundStyle(.white)

                    Text(L10n.Profile.Pro.unlimitedAccess)
                        .font(.bodyS)
                        .foregroundStyle(Color.textOnDark)
                        .lineSpacing(2)
                }

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accent)
            }
            .padding(20)
            .background(Color.surfaceDark)
            .clipShape(.rect(cornerRadius: 20))
        } else {
            Button { showPaywall = true } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.Profile.Pro.getTitle)
                            .font(.headingL)
                            .foregroundStyle(.white)

                        Text(L10n.Profile.Pro.getSubtitle)
                            .font(.bodyS)
                            .foregroundStyle(Color.textOnDark)
                            .lineSpacing(2)

                        Text(L10n.Profile.Pro.upgrade)
                            .font(.buttonM)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.surfaceWhite)
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }

                    Spacer()

                    Image("premiumIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                }
                .padding(20)
                .background(Color.surfaceDark)
                .clipShape(.rect(cornerRadius: 20))
            }
            .buttonStyle(ScaleButtonStyle())
            .sheet(isPresented: $showPaywall) {
                PaywallView(subscriptionManager: subscriptionManager)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    NeuraProCard()
        .padding()
}
