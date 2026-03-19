import SwiftUI

struct EmergencyCardBanner: View {
    let onTap: () -> Void

    private let cardRed = Color(hex: "F14D42")

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Medical star icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cardRed)
                        .frame(width: 46, height: 46)

                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Emergency Card")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Text("Quick access to vital health info")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    EmergencyCardBanner(onTap: {})
        .padding(20)
        .background(Color.backgroundPrimary)
}
