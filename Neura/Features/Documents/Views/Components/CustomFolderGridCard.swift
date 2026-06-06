import SwiftUI

struct CustomFolderGridCard: View {
    let folder: CustomFolder
    let count: Int

    /// Tints mirror the gradient palette used by the built-in category folders.
    private static let tints: [Color] = [
        Color(hex: "BD6B73"), Color(hex: "456990"), Color(hex: "6B9080"),
        Color(hex: "536B78"), Color(hex: "8B7E8F"), Color(hex: "C08552"),
        Color(hex: "5C6784"), Color(hex: "A26769")
    ]

    private var tint: Color {
        Self.tints[folder.colorSeed % Self.tints.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: folder.iconSymbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.15))
                .clipShape(.rect(cornerRadius: 12))

            HStack(spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("(\(count))")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "F3EDE6"))
        .clipShape(.rect(cornerRadius: 16))
    }
}
