import SwiftUI

struct NeuraProCard: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        if subscriptionManager.isPro {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Neura Pro")
                        .font(.headingL)
                        .foregroundColor(.white)

                    Text("You have unlimited access.\nThank you for your support!")
                        .font(.bodyS)
                        .foregroundColor(Color.textOnDark)
                        .lineSpacing(2)
                }

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accent)
            }
            .padding(20)
            .background(Color.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            Button { showPaywall = true } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Get Neura Pro")
                            .font(.headingL)
                            .foregroundColor(.white)

                        Text("Unlimited medical documents.\nShare them with doctors anytime.")
                            .font(.bodyS)
                            .foregroundColor(Color.textOnDark)
                            .lineSpacing(2)

                        Text("Upgrade to Pro")
                            .font(.buttonM)
                            .foregroundColor(.textPrimary)
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
                .clipShape(RoundedRectangle(cornerRadius: 20))
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
