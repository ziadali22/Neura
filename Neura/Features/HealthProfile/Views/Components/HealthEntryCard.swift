import SwiftUI

struct HealthEntryCard: View {
    let title: String
    let details: [(label: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)

            ForEach(Array(details.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.label)
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                    Text(row.value)
                        .font(.bodyL)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
    }
}
