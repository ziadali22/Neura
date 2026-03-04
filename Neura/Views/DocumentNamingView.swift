//
//  DocumentNamingView.swift
//  Neura
//
//  Created by ziad on 03/03/2026.
//

import SwiftUI

struct DocumentNamingView: View {
    @Environment(\.dismiss) private var dismiss
    let scannedImages: [UIImage]
    let category: String
    let onSave: (String) -> Void

    @State private var documentName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 40)

                    Text("Name Your File")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Scanned \(scannedImages.count) page\(scannedImages.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Preview thumbnails
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

                                Text("Page \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 160)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("File Name")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    TextField("Enter file name", text: $documentName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            saveDocument()
                        }
                }
                .padding(.horizontal, 20)

                // Category info
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text("Saving to \(category)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Save button
                Button {
                    saveDocument()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save File")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray
                        : Color.blue
                    )
                    .cornerRadius(16)
                }
                .disabled(documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(red: 0.99, green: 0.98, blue: 0.97))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                // Set default name based on category and date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy"
                let dateString = dateFormatter.string(from: Date())

                switch category {
                case "Blood Tests":
                    documentName = "Blood Test - \(dateString)"
                case "Prescriptions":
                    documentName = "Prescription - \(dateString)"
                case "Consultations":
                    documentName = "Consultation - \(dateString)"
                case "Hospitalization":
                    documentName = "Hospitalization - \(dateString)"
                case "Tests & Imaging":
                    documentName = "Test - \(dateString)"
                default:
                    documentName = "Document - \(dateString)"
                }

                // Focus text field after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private func saveDocument() {
        let trimmedName = documentName.trimmingCharacters(in: .whitespacesAndNewlines)
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
