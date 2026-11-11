import SwiftUI

/// The app's primary call-to-action button: a full-width accent capsule with a
/// white label and an optional leading or trailing SF Symbol. Use this for the
/// main action on a screen so every primary button shares one shape and radius.
struct PrimaryButton: View {
    enum IconPlacement { case leading, trailing }

    let title: String
    var systemImage: String? = nil
    var iconPlacement: IconPlacement = .leading
    var labelFont: Font = .buttonL
    let action: () -> Void

    /// Blank names count as no icon, so a hidden symbol never keeps a slot.
    private var iconName: String? {
        guard let systemImage else { return nil }
        let trimmed = systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(labelFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background { iconBesideTitle }
                .background(Color.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    /// Drawn beside the title without joining its layout, so hiding it cannot shift the label.
    @ViewBuilder
    private var iconBesideTitle: some View {
        if let iconName {
            Text(title)
                .font(labelFont)
                .foregroundStyle(.clear)
                .overlay(alignment: iconPlacement == .leading ? .leading : .trailing) {
                    icon(iconName)
                        .alignmentGuide(iconPlacement == .leading ? .leading : .trailing) { dimensions in
                            if iconPlacement == .leading {
                                dimensions[.trailing] + 8
                            } else {
                                dimensions[.leading] - 8
                            }
                        }
                }
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
    }
}
