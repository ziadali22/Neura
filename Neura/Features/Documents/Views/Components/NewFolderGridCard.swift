import SwiftUI

struct NewFolderGridCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("New Folder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accent)

                Text("Create custom")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.accent.opacity(0.06))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    Color.accent.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
    }
}

#Preview {
    NewFolderGridCard()
        .padding()
        .background(Color.backgroundPrimary)
}
