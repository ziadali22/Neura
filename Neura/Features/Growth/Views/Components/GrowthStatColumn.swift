import SwiftUI

struct GrowthStatColumn: View {
    enum LabelPlacement {
        case above
        case below
    }

    let label: String
    let value: String
    let delta: String?
    var valueFont: Font = .headingL
    var labelPlacement: LabelPlacement = .above

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if labelPlacement == .above { labelText }
            valueRow
            if labelPlacement == .below { labelText }
        }
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label)
            .font(.captionS)
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .tracking(1.5)
    }

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(valueFont)
                .foregroundStyle(Color.textPrimary)
            if let delta {
                Text(delta)
                    .font(.headingXS)
                    .foregroundStyle(Color.accent)
            }
        }
    }
}
