import SwiftUI

struct GlassIconButton<Content: View>: View {
    var size: CGFloat = 64
    var badge: Bool = false

    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {

            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .glassEffect()

                content()
            }
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(.regularMaterial)
                    .glassEffect()
                    .scaleEffect(1.65)
                    .blur(radius: 8)
                    .opacity(0.75)
            }

            if badge {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .offset(x: 2, y: -2)
            }
        }
    }
}
