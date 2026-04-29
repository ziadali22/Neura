import SwiftUI

// MARK: - Document Metadata

struct DocumentMetadata {
    var name: String = ""
    var category: DocumentCategory?
    var specialization: MedicalSpecialization = .other
    var doctorName: String = ""
    var notes: String = ""
    var documentDate: Date = Date()
}

// MARK: - Preview Content

enum DocumentPreviewContent {
    case scannedImages([UIImage])
    case importedFile(URL)
}

// MARK: - Document Metadata View

struct DocumentMetadataView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: DocumentPreviewContent
    let onSave: (DocumentMetadata, DocumentPreviewContent) -> Void

    @State private var metadata = DocumentMetadata()
    @State private var scannedImages: [UIImage] = []
    @State private var showScanner = false
    @State private var showDatePicker = false
    @State private var showSpecializationPicker = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, doctor, notes
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    previewSection
                    categorySection
                    specializationSection
                    dateSection
                    nameSection
                    doctorSection
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSpecializationPicker) {
                SpecializationPickerView(selected: $metadata.specialization)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textPrimary)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .fontWeight(.medium)
                    }
                }
            }
            .onAppear {
                if case .scannedImages(let images) = preview {
                    scannedImages = images
                }
                metadata.name = defaultName
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { result in
                if case .success(let newImages) = result {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scannedImages.append(contentsOf: newImages)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Group {
            switch preview {
            case .scannedImages:
                scannedImagesPreview
            case .importedFile(let url):
                importedFilePreview(url: url)
            }
        }
        .padding(.top, 8)
    }

    private var scannedImagesPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(scannedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.stroke, lineWidth: 1)
                            )

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if scannedImages.indices.contains(index) {
                                    scannedImages.remove(at: index)
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }

                // Add more pages button
                Button {
                    showScanner = true
                } label: {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accent, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accent.opacity(0.06))
                        )
                        .frame(width: 90, height: 120)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.accent)
                        )
                }
            }
        }
        .padding(.horizontal, -20) // extend beyond parent padding
        .padding(.horizontal, 20)  // re-add padding inside scroll content
    }

    private func importedFilePreview(url: URL) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: fileIcon(for: url))
                    .font(.system(size: 28))
                    .foregroundColor(.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.bodyL)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(url.pathExtension.uppercased())
                    .font(.captionS)
                    .foregroundColor(.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DocumentCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            metadata.category = (metadata.category == cat) ? nil : cat
                        }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
//                                Circle()
//                                    .fill(cat.color.opacity(0.15))
//                                    .frame(width: 28, height: 28)

                                if let asset = cat.assetIcon {
                                    Image(asset)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(cat.color)
                                }
                            }

                            Text(cat.localizedName)
                                .font(.bodyS)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            metadata.category == cat
                            ? Color.surfaceDark
                            : Color.surfaceWhite
                        )
                        .foregroundColor(
                            metadata.category == cat ? .white : .textPrimary
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Specialization Section

    private var specializationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Specialization")
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            Button {
                focusedField = nil
                showSpecializationPicker = true
            } label: {
                HStack {
                    Text(metadata.specialization.rawValue)
                        .font(.bodyL)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textTertiary)
                }
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Date")
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDatePicker.toggle()
                }
                focusedField = nil
            } label: {
                HStack {
                    Text(dateDisplayText)
                        .font(.bodyL)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textTertiary)
                        .rotationEffect(.degrees(showDatePicker ? 90 : 0))
                }
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }

            if showDatePicker {
                DatePicker(
                    "",
                    selection: $metadata.documentDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.accent)
                .labelsHidden()
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private var dateDisplayText: String {
        if Calendar.current.isDateInToday(metadata.documentDate) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: metadata.documentDate)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Name")
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            TextField("Blood Test", text: $metadata.name)
                .focused($focusedField, equals: .name)
                .font(.bodyL)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .submitLabel(.next)
                .onSubmit { focusedField = .doctor }
        }
    }

    // MARK: - Doctor Section

    private var doctorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Doctor Name")
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            TextField("e.g. Dr. Sarah Johnson", text: $metadata.doctorName)
                .focused($focusedField, equals: .doctor)
                .font(.bodyL)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .submitLabel(.next)
                .onSubmit { focusedField = .notes }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            ZStack(alignment: .topLeading) {
                if metadata.notes.isEmpty {
                    Text("Additional details about this document")
                        .font(.bodyL)
                        .foregroundColor(.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $metadata.notes)
                    .font(.bodyL)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }
            .padding(16)
            .background(Color.surfaceWhite)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button { save() } label: {
            Text("Save Document")
                .font(.buttonL)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(canSave ? Color.accent : Color.textTertiary)
                .cornerRadius(18)
        }
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(
            Color.backgroundPrimary
                .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
        )
    }

    // MARK: - Helpers

    private var canSave: Bool {
        let hasName = !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch preview {
        case .scannedImages:
            return hasName && !scannedImages.isEmpty
        case .importedFile:
            return hasName
        }
    }

    private var defaultName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let date = formatter.string(from: Date())

        switch preview {
        case .scannedImages: return "Scan - \(date)"
        case .importedFile(let url):
            let name = url.deletingPathExtension().lastPathComponent
            return name.isEmpty ? "Document - \(date)" : name
        }
    }

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }

    private func save() {
        guard canSave else { return }
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var trimmed = metadata
        trimmed.name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed.doctorName = metadata.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed.notes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalPreview: DocumentPreviewContent
        switch preview {
        case .scannedImages:
            finalPreview = .scannedImages(scannedImages)
        case .importedFile:
            finalPreview = preview
        }

        onSave(trimmed, finalPreview)
        dismiss()
    }
}

// MARK: - Specialization Picker View

private struct SpecializationPickerView: View {
    @Binding var selected: MedicalSpecialization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(MedicalSpecialization.allCases) { spec in
                    Button {
                        selected = spec
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: spec.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 28, alignment: .center)

                            Text(spec.rawValue)
                                .font(.bodyL)
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        selected == spec ? Color.accent : Color.textTertiary.opacity(0.35),
                                        lineWidth: 2
                                    )
                                    .frame(width: 22, height: 22)

                                if selected == spec {
                                    Circle()
                                        .fill(Color.accent)
                                        .frame(width: 13, height: 13)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if spec != MedicalSpecialization.allCases.last {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Specialization")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("Scanned Images") {
    DocumentMetadataView(
        preview: .scannedImages([UIImage(systemName: "doc.fill")!]),
        onSave: { _, _ in }
    )
}

#Preview("Imported File") {
    DocumentMetadataView(
        preview: .importedFile(URL(fileURLWithPath: "/tmp/report.pdf")),
        onSave: { _, _ in }
    )
}
