import SwiftUI

struct ScanProcessingView: View {
    let isProcessing: Bool

    var body: some View {
        if isProcessing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                    }

                    Text("Saving document...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    ScanProcessingView(isProcessing: true)
}
