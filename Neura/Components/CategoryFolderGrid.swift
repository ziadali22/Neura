//
//  CategoryFolderGrid.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

struct CategoryFolderGrid: View {
    let folders: [CategoryFolder]
    let onAddFolder: () -> Void
    @EnvironmentObject var viewModel: DocsViewModel

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(folders) { folder in
                NavigationLink {
                    CategoryDetailView(folder: folder)
                        .environmentObject(viewModel)
                } label: {
                    FolderCard(folder: folder)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // New Folder Button
            Button(action: onAddFolder) {
                AddFolderCard()
            }
        }
        .padding(.horizontal, 20)
    }
}

struct FolderCard: View {
    let folder: CategoryFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon in colored circle - top left
            Image(folder.icon)
                .resizable()
                .frame(width: 30, height: 30)
                .padding(.top, 16)
                .padding(.leading, 16)

            Spacer()

            // Folder name with count - leading aligned
            Text("\(folder.name) (\(folder.count))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .lineLimit(2)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .background(Color(red: 0.96, green: 0.95, blue: 0.93))
        .cornerRadius(12)
    }
}

struct AddFolderCard: View {
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plus icon - top left
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color(red: 0.93, green: 0.42, blue: 0.36))
                .padding(.top, 16)
                .padding(.leading, 16)
                .padding(.bottom, 8)

            Spacer()

            // Text - leading aligned
            Text("New Folder")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .background(Color(red: 0.96, green: 0.95, blue: 0.93))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundColor(Color(red: 0.93, green: 0.42, blue: 0.36).opacity(0.5))
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    @Previewable @StateObject var viewModel = DocsViewModel()

    return NavigationStack {
        CategoryFolderGrid(
            folders: [
                CategoryFolder(
                    name: "Blood Tests",
                    count: 13,
                    icon: "drop.fill",
                    gradientColors: [Color(hex:"BD6B73"), Color(hex:"BD6B73")]
                ),
                CategoryFolder(
                    name: "Prescriptions",
                    count: 2,
                    icon: "doc.text.fill",
                    gradientColors: [Color(hex: "456990"), Color(hex: "456990")]
                )
            ],
            onAddFolder: {}
        )
        .environmentObject(viewModel)
        .background(Color(red: 0.99, green: 0.98, blue: 0.97))
    }
}
