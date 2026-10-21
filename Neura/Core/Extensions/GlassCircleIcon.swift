import SwiftUI

struct GlassIconButton<Content: View>: View {
    var size: CGFloat = 64
    var badge: Bool = false

    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {

            ZStack {
                Circle()
                    .fill(Color.surfaceWhite)

                content()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)

            if badge {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .offset(x: 2, y: -2)
            }
        }
    }
}
