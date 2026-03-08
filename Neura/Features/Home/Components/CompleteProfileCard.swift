import SwiftUI

struct CompleteProfileCard: View {
    @State private var lineAnimation = false
    @State private var arrowBounce = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.orange, Color.white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: lineAnimation ? 186 : 0, height: 1)
                .offset(x: 73, y: 1)

                HStack(spacing: 13) {
                    Image("profile")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(lineAnimation ? 0 : -10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete your profile")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#1f1f1f"))

                        Text("Add one more element to complete your medical profile.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#4a4a4a"))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            arrowBounce.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#1f1f1f"))
                            .clipShape(Circle())
                    }
                    .scaleEffect(arrowBounce ? 0.9 : 1.0)
                    .offset(x: arrowBounce ? 5 : 0)
                }
                .padding(16)
                .frame(height: 90)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.gray.opacity(0.25), radius: 12, x: 0, y: 4)

                LinearGradient(
                    colors: [Color.orange, Color.white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: lineAnimation ? 186 : 0, height: 1)
                .offset(x: 133, y: -1)
                .scaleEffect(x: 1, y: -1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                lineAnimation = true
            }
        }
    }
}

#Preview {
    CompleteProfileCard()
        .padding()
}
