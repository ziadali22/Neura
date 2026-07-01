import SwiftUI

/// One-time promo card shown on Home introducing the health calendar.
struct CalendarPromoPopover: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image("calendarImage")
                .resizable()
                .scaledToFit()
                .frame(height: 132)
                .frame(maxWidth: .infinity)

            Text(L10n.Calendar.promoTitle)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onOpen) {
                Text(L10n.Calendar.promoOpen)
                    .font(.buttonM)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .frame(width: 220)
        .background(Color(hex: "F3EDE6"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.7), in: Circle())
            }
            .padding(8)
        }
    }
}
