import SwiftUI

struct SplashView: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 1
    @State private var scale: Double = 1

    var body: some View {
        ZStack {
            Color.accent
                .ignoresSafeArea()

            Image("n")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.white)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .scaleEffect(scale)
        }
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    opacity = 0
                    scale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    SplashView(isPresented: .constant(true))
}
