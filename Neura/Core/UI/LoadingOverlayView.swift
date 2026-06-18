import SwiftUI

/// Full-screen modal loading overlay using the app design system.
/// Show while a blocking async task (e.g. account deletion) is in progress.
struct LoadingOverlayView: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.surfaceWhite)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
                            .scaleEffect(1.5)
                    }

                    Text(message)
                        .font(.bodyL)
                        .foregroundStyle(Color.surfaceWhite)
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    LoadingOverlayView(isLoading: true, message: "Deleting your account…")
}
