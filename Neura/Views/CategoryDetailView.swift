//
//  CategoryDetailView.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

struct CategoryDetailView: View {
    let folder: CategoryFolder
    @EnvironmentObject var viewModel: DocsViewModel
    @State private var groupedDocuments: [GroupedDocument] = []
    @State private var appearAnimations: [Bool] = []
    @State private var selectedDocument: Document?
    @State private var showImageViewer = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if groupedDocuments.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: folder.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 60)

                        Text("No Documents Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Scan your first document to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(Array(groupedDocuments.enumerated()), id: \.element.id) { index, group in
                        VStack(alignment: .leading, spacing: 12) {
                            // Month Header
                            Text(group.month)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                                .padding(.horizontal, 20)

                            // Documents
                            VStack(spacing: 8) {
                                ForEach(group.documents) { document in
                                    DocumentDetailRow(
                                        document: document,
                                        icon: folder.icon,
                                        gradientColors: folder.gradientColors
                                    ) {
                                        selectedDocument = document
                                        showImageViewer = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .opacity(index < appearAnimations.count && appearAnimations[index] ? 1 : 0)
                        .offset(y: index < appearAnimations.count && appearAnimations[index] ? 0 : 20)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(red: 0.99, green: 0.98, blue: 0.97))
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottomTrailing) {
            // Add New File Button
            Button {
                viewModel.scanFromFolder(folder)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add New File")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: folder.gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: folder.gradientColors.first?.opacity(0.4) ?? .clear, radius: 12, x: 0, y: 6)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            loadDocuments()
            animateAppearance()
        }
        .onChange(of: viewModel.documents) { _ in
            loadDocuments()
            animateAppearance()
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let document = selectedDocument {
                DocumentImageViewer(document: document) {
                    viewModel.deleteDocument(document)
                }
            }
        }
    }

    private func loadDocuments() {
        // Get real documents from ViewModel
        guard let categoryDocuments = viewModel.documents[folder.name] else {
            groupedDocuments = []
            appearAnimations = []
            return
        }

        // Group documents by month
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"

        var grouped: [String: [Document]] = [:]

        for document in categoryDocuments {
            let monthKey = dateFormatter.string(from: document.date)
            if grouped[monthKey] == nil {
                grouped[monthKey] = []
            }
            grouped[monthKey]?.append(document)
        }

        // Sort by month (most recent first)
        let sortedMonths = grouped.keys.sorted { month1, month2 in
            guard let doc1 = grouped[month1]?.first,
                  let doc2 = grouped[month2]?.first else {
                return false
            }
            return doc1.date > doc2.date
        }

        groupedDocuments = sortedMonths.map { month in
            GroupedDocument(
                month: month,
                documents: grouped[month] ?? []
            )
        }

        appearAnimations = Array(repeating: false, count: groupedDocuments.count)
    }

    private func animateAppearance() {
        for index in 0..<groupedDocuments.count {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1)) {
                if index < appearAnimations.count {
                    appearAnimations[index] = true
                }
            }
        }
    }
}

struct DocumentDetailRow: View {
    let document: Document
    let icon: String
    let gradientColors: [Color]
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var thumbnailImage: UIImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail or Icon
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        Circle()
                            .fill(gradientColors.first?.opacity(0.15) ?? Color.orange.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(gradientColors.first ?? .orange)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))

                    HStack(spacing: 4) {
                        Text(formatDate(document.date))
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.48))

                        if document.pageCount > 1 {
                            Text("•")
                                .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.48))

                            Text("\(document.pageCount) pages")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.48))
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.48))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.gray.opacity(0.1), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let thumbnailPath = document.thumbnailURL else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let image = DocumentFileManager.shared.loadImage(from: thumbnailPath)
            DispatchQueue.main.async {
                self.thumbnailImage = image
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Models
struct GroupedDocument: Identifiable {
    let id = UUID()
    let month: String
    let documents: [Document]
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            folder: CategoryFolder(
                name: "Blood Tests",
                count: 13,
                icon: "drop.fill",
                gradientColors: [.orange, .orange.opacity(0.7)]
            )
        )
    }
}
