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
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main card with gradient background
            VStack(alignment: .leading, spacing: 0) {
                // White header bar (like in screenshot)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 24)
                    .padding([.horizontal, .top], 10)

                Spacer()

                // Icon in circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 40, height: 40)

                    Image(systemName: folder.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 14)
                .padding(.bottom, 6)

                // Folder name
                Text(folder.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 2)

                // Document count
                Text("\(folder.count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(
                LinearGradient(
                    colors: folder.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(18)
            .shadow(color: folder.gradientColors.first?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 3)
        }
    }
}

struct AddFolderCard: View {
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // White header bar
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.3))
                .frame(height: 24)
                .padding([.horizontal, .top], 10)

            Spacer()

            // Plus icon in circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 40)

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.leading, 14)
            .padding(.bottom, 6)

            // Text
            Text("New Folder")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundColor(.white.opacity(0.5))
        )
        .shadow(color: Color.gray.opacity(0.2), radius: 8, x: 0, y: 3)
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
