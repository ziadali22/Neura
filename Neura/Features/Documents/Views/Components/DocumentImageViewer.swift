import SwiftUI
import PDFKit

// Legacy viewer kept for backward compatibility.
// New pipeline uses DocumentViewerView.

struct DocumentImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let document: Document
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if document.isPDF {
                    PDFViewerContainer(url: document.fileURL)
                        .ignoresSafeArea(edges: .bottom)
                } else if document.isImage {
                    ImagePageView(url: document.fileURL)
                }
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { shareDocument() } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }

                        Button { showDeleteConfirmation = true } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(L10n.Documents.Viewer.deleteTitle, isPresented: $showDeleteConfirmation) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Common.delete, role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text(L10n.Documents.Viewer.deleteMessage)
            }
        }
    }

    private func shareDocument() {
        guard document.fileExists else { return }

        let activityVC = UIActivityViewController(
            activityItems: [document.fileURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Image Page

private struct ImagePageView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = lastScale * value }
                            .onEnded { _ in
                                lastScale = scale
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
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            Task.detached(priority: .userInitiated) {
                let data = try? Data(contentsOf: url)
                let loaded = data.flatMap { UIImage(data: $0) }
                await MainActor.run { image = loaded }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DocumentImageViewer(
        document: Document(
            name: "Blood Test Results",
            fileURL: URL(fileURLWithPath: "/tmp/preview.pdf"),
            documentType: .pdf,
            category: .bloodTests
        ),
        onDelete: {}
    )
}
