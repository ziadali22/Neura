import SwiftUI

struct NeuraProCard: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Get Neura Pro")
                    .font(.headingL)
                    .foregroundColor(.white)

                Text("Unlimited medical documents.\nShare them with doctors anytime.")
                    .font(.bodyS)
                    .foregroundColor(Color.textOnDark)
                    .lineSpacing(2)

                Button {
                    // TODO: Navigate to subscription
                } label: {
                    Text("Upgrade to Pro")
                        .font(.buttonM)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.surfaceWhite)
                        .clipShape(Capsule())
                }
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
}

#Preview {
    NeuraProCard()
        .padding()
}
