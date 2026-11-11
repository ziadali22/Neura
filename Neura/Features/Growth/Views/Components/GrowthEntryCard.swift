import SwiftUI

struct GrowthEntryCard: View {
    let entry: GrowthEntry
    let photo: UIImage?
    let previous: GrowthEntry?
    /// Tapping the photo opens the full-frame preview. Tapping anywhere else on the
    /// card (padding, date, stats) edits the entry. The two are sibling buttons —
    /// a nested button inside another button's label never receives taps in SwiftUI.
    var onPreviewPhoto: (() -> Void)?
    var onEdit: (() -> Void)?

    private enum Metrics {
        static let photoHeight: CGFloat = 200
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let photo, let onPreviewPhoto {
                Button(action: onPreviewPhoto) { photoView(photo) }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(L10n.Growth.viewPhoto)
            } else {
                photoPlaceholder
            }

            if let onEdit {
                Button(action: onEdit) { details }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityHint(L10n.Growth.edit)
            } else {
                details
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cardBackground }
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
    }

    /// Fills the chrome around the photo so a tap on the card padding still edits.
    @ViewBuilder
    private var cardBackground: some View {
        if let onEdit {
            Button(action: onEdit) {
                Color.surfaceWhite
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        } else {
            Color.surfaceWhite
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.dateFormatter.string(from: entry.date))
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)

            HStack(alignment: .top, spacing: 24) {
                GrowthStatColumn(
                    label: L10n.Growth.height,
                    value: entry.heightLabel,
                    delta: entry.heightDelta(from: previous)
                )
                GrowthStatColumn(
                    label: L10n.Growth.weight,
                    value: entry.weightLabel,
                    delta: entry.weightDelta(from: previous)
                )
                Spacer(minLength: 0)
            }

            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func photoView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.photoHeight)
            .clipped()
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
            .overlay(alignment: .bottomTrailing) { expandBadge }
            .accessibilityHidden(true)
    }

    private var photoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundCard)
                .frame(height: 160)
            Image(systemName: "camera")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(L10n.Growth.photo)
    }

    private var expandBadge: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(.black.opacity(0.4), in: Circle())
            .padding(8)
            .accessibilityHidden(true)
    }
}
