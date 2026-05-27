import SwiftUI

struct CategoryFolderGridCard: View {
    let category: DocumentCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let assetName = category.assetIcon {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: category.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(category.color)
                    .frame(width: 48, height: 48)
            }

            HStack(spacing: 4) {
                Text(category.localizedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("(\(count))")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "F3EDE6"))
        .clipShape(.rect(cornerRadius: 16))
    }
}
