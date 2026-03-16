import SwiftUI

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let folders: [CategoryFolder]
    let onSelectFolder: (CategoryFolder) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Select Category")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                Text("Choose where to save your scanned document")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(folders) { folder in
                            CategoryPickerRow(folder: folder) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onSelectFolder(folder)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(red: 0.99, green: 0.98, blue: 0.97))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Picker Row

private struct CategoryPickerRow: View {
    let folder: CategoryFolder
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    LinearGradient(
                        colors: folder.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 56, height: 56)
                    .cornerRadius(14)

                    Image(systemName: folder.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(folder.count) document\(folder.count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    CategoryPickerSheet(
        folders: [
            CategoryFolder(
                name: "Blood Tests",
                count: 13,
                icon: "drop.fill",
                gradientColors: [.orange, .orange.opacity(0.7)]
            ),
            CategoryFolder(
                name: "Prescriptions",
                count: 2,
                icon: "doc.text.fill",
                gradientColors: [.yellow, .yellow.opacity(0.7)]
            )
        ],
        onSelectFolder: { _ in }
    )
}
