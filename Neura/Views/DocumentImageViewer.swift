//
//  DocumentImageViewer.swift
//  Neura
//
//  Created by ziad on 03/03/2026.
//

import SwiftUI
import PDFKit

struct DocumentImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let document: Document
    let onDelete: () -> Void

    @State private var currentPage = 0
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Route based on document type
                if let pdfURL = document.pdfURL {
                    // PDF Viewer
                    PDFViewerContainer(pdfURL: pdfURL)
                } else if document.imageURLs.count > 1 {
                    // Multi-page image viewer with TabView (backward compatibility)
                    TabView(selection: $currentPage) {
                        ForEach(Array(document.imageURLs.enumerated()), id: \.offset) { index, imagePath in
                            DocumentImagePage(imagePath: imagePath)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                } else if let imagePath = document.imageURLs.first {
                    // Single page image viewer (backward compatibility)
                    DocumentImagePage(imagePath: imagePath)
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button
                        Button {
                            shareDocument()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }

                        // Delete button
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Delete Document", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this document? This action cannot be undone.")
            }
        }
    }

    private func shareDocument() {
        var itemsToShare: [URL] = []

        // Prefer PDF if available
        if let pdfURL = document.pdfURL {
            let url = URL(fileURLWithPath: pdfURL)
            if FileManager.default.fileExists(atPath: url.path) {
                itemsToShare.append(url)
            }
        } else {
            // Fallback to images (backward compatibility)
            for imagePath in document.imageURLs {
                let url = URL(fileURLWithPath: imagePath)
                if FileManager.default.fileExists(atPath: url.path) {
                    itemsToShare.append(url)
                }
            }
        }

        guard !itemsToShare.isEmpty else { return }

        let activityVC = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

struct DocumentImagePage: View {
    let imagePath: String

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Reset zoom if too small
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = DocumentFileManager.shared.loadImage(from: imagePath)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}

#Preview {
    DocumentImageViewer(
        document: Document(
            title: "Blood Test - Mar 3, 2026",
            date: Date(),
            imageURLs: [],
            category: "Blood Tests"
        ),
        onDelete: {}
    )
}
