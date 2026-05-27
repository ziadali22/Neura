import SwiftUI

struct DocumentNamingView: View {
    @Environment(\.dismiss) private var dismiss
    let scannedImages: [UIImage]
    let category: String
    let onSave: (String) -> Void

    @State private var documentName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                thumbnailStrip
                nameInput
                categoryInfo

                Spacer()

                saveButton
            }
            .background(Color(red: 0.99, green: 0.98, blue: 0.97))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .foregroundColor(.primary)
                }
            }
            .onAppear {
                documentName = defaultDocumentName
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text(L10n.Documents.Naming.title)
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.Documents.Naming.scannedPages(scannedImages.count))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(scannedImages.enumerated()), id: \.offset) { index, image in
                    VStack(spacing: 4) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Text(L10n.Documents.Naming.page(index + 1))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 160)
    }

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Documents.Naming.fileName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TextField(L10n.Documents.Naming.fileNamePlaceholder, text: $documentName)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .padding(16)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit { saveDocument() }
        }
        .padding(.horizontal, 20)
    }

    private var categoryInfo: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            Text(L10n.Documents.Naming.savingTo(category))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private var saveButton: some View {
        Button { saveDocument() } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(L10n.Documents.Naming.saveFile)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(trimmedName.isEmpty ? Color.gray : Color.blue)
            .cornerRadius(16)
        }
        .disabled(trimmedName.isEmpty)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private var trimmedName: String {
        documentName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultDocumentName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: Date())

        switch category {
        case "Blood Tests": return "Blood Test - \(dateString)"
        case "Prescriptions": return "Prescription - \(dateString)"
        case "Consultations": return "Consultation - \(dateString)"
        case "Hospitalization": return "Hospitalization - \(dateString)"
        case "Tests & Imaging": return "Test - \(dateString)"
        default: return "Document - \(dateString)"
        }
    }

    private func saveDocument() {
        guard !trimmedName.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSave(trimmedName)
        dismiss()
    }
}

#Preview {
    DocumentNamingView(
        scannedImages: [UIImage(systemName: "doc.fill")!],
        category: "Blood Tests",
        onSave: { _ in }
    )
}
