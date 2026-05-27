import SwiftUI

struct CustomFolderGridCard: View {
    let folder: CustomFolder
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.accent)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
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
