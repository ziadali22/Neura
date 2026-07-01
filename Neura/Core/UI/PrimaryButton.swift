import SwiftUI

/// The app's primary call-to-action button: a full-width accent capsule with a
/// white label and an optional leading or trailing SF Symbol. Use this for the
/// main action on a screen so every primary button shares one shape and radius.
struct PrimaryButton: View {
    enum IconPlacement { case leading, trailing }

    let title: String
    var systemImage: String? = nil
    var iconPlacement: IconPlacement = .leading
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage, iconPlacement == .leading {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.buttonL)
                if let systemImage, iconPlacement == .trailing {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accent)
            .clipShape(Capsule())
            .shadow(color: Color.accent.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
