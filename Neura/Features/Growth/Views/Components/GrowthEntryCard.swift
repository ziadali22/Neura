import SwiftUI

struct GrowthEntryCard: View {
    let entry: GrowthEntry
    let photo: UIImage?
    let previous: GrowthEntry?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photoBlock

            Text(Self.dateFormatter.string(from: entry.date))
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)

            HStack(spacing: 16) {
                measurement(label: L10n.Growth.height, value: entry.heightLabel, delta: heightDelta)
                measurement(label: L10n.Growth.weight, value: entry.weightLabel, delta: weightDelta)
            }

            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
    }

    @ViewBuilder
    private var photoBlock: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .clipShape(.rect(cornerRadius: 12))
        } else {
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
    }

    private func measurement(label: String, value: String, delta: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
            if let delta {
                Text(delta)
                    .font(.captionS)
                    .foregroundStyle(Color.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heightDelta: String? {
        guard let previous else { return nil }
        let change = entry.heightCm - previous.heightCm
        guard change != 0 else { return nil }
        return change > 0 ? "+\(change) cm" : "\(change) cm"
    }

    private var weightDelta: String? {
        guard let previous else { return nil }
        let change = entry.weightKg - previous.weightKg
        guard abs(change) >= 0.05 else { return nil }
        let formatted = GrowthEntry.formatWeight(abs(change))
        return change > 0 ? "+\(formatted)" : "-\(formatted)"
    }
}
