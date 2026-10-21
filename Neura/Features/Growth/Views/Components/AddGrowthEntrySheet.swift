import PhotosUI
import SwiftUI

struct AddGrowthEntrySheet: View {
    private struct IdentifiableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private enum MeasurementField: Identifiable {
        case height
        case weight

        var id: Self { self }

        var title: String {
            switch self {
            case .height: L10n.Growth.height
            case .weight: L10n.Growth.weight
            }
        }
    }

    let existing: GrowthEntry?
    let defaultHeightCm: Int
    let defaultWeightKg: Double
    let existingPhoto: UIImage?
    let onSave: (GrowthEntry, UIImage?, Bool) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var heightLabel: String
    @State private var weightLabel: String
    @State private var notes: String
    @State private var photo: UIImage?
    @State private var removePhoto = false
    @State private var didPickNewPhoto = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imagePendingCrop: IdentifiableImage?
    @State private var showDeleteConfirmation = false
    @State private var activeWheel: MeasurementField?

    init(
        existing: GrowthEntry?,
        defaultHeightCm: Int,
        defaultWeightKg: Double,
        existingPhoto: UIImage?,
        onSave: @escaping (GrowthEntry, UIImage?, Bool) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existing = existing
        self.defaultHeightCm = defaultHeightCm
        self.defaultWeightKg = defaultWeightKg
        self.existingPhoto = existingPhoto
        self.onSave = onSave
        self.onDelete = onDelete
        _date = State(initialValue: existing?.date ?? Date())
        _heightLabel = State(initialValue: existing?.heightLabel ?? "\(defaultHeightCm) cm")
        _weightLabel = State(initialValue: existing?.weightLabel ?? GrowthEntry.formatWeight(defaultWeightKg))
        _notes = State(initialValue: existing?.notes ?? "")
        _photo = State(initialValue: existingPhoto)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        dateFieldRow

                        measurementFieldRow(
                            title: L10n.Growth.height,
                            value: heightLabel,
                            action: openHeightPicker
                        )

                        measurementFieldRow(
                            title: L10n.Growth.weight,
                            value: weightLabel,
                            action: openWeightPicker
                        )
                    }

                    fieldSection(L10n.Growth.photo) {
                        photoPicker
                    }

                    fieldSection(L10n.Growth.notes) {
                        TextField(L10n.Growth.notesPlaceholder, text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if existing != nil, onDelete != nil {
                        Button(L10n.Growth.delete, role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .font(.bodyL)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(existing == nil ? L10n.Growth.add : L10n.Growth.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        persist()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(canSave ? Color.accent : Color.textTertiary)
                            .clipShape(Circle())
                    }
                    .disabled(!canSave)
                    .accessibilityLabel(L10n.Common.save)
                }
            }
            .alert(L10n.Common.areYouSure, isPresented: $showDeleteConfirmation) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Common.delete, role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text(L10n.Common.thisActionCannotBeUndone)
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        imagePendingCrop = IdentifiableImage(image: uiImage)
                    }
                    selectedPhotoItem = nil
                }
            }
            .sheet(item: $activeWheel) { field in
                switch field {
                case .height:
                    WheelPickerSheet(
                        fieldName: field.title,
                        values: WheelPickerSheet.heightValues,
                        current: heightLabel
                    ) { heightLabel = $0 }
                    .presentationDragIndicator(.hidden)
                case .weight:
                    GrowthWeightPickerSheet(
                        currentKg: GrowthEntry.parseWeightKg(weightLabel) ?? defaultWeightKg
                    ) { weightLabel = GrowthEntry.formatWeight($0) }
                    .presentationDragIndicator(.hidden)
                }
            }
            .fullScreenCover(item: $imagePendingCrop) { wrapped in
                GrowthPhotoCropView(
                    image: wrapped.image,
                    onCancel: { imagePendingCrop = nil },
                    onConfirm: { cropped in
                        photo = cropped
                        removePhoto = false
                        didPickNewPhoto = true
                        imagePendingCrop = nil
                    }
                )
            }
        }
    }

    private var displayedPhoto: UIImage? {
        removePhoto ? nil : photo
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let displayedPhoto {
                Image(uiImage: displayedPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 12))

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(L10n.Growth.changePhoto)
                            .font(.headingXS)
                            .foregroundStyle(Color.accent)
                    }

                    Spacer(minLength: 8)

                    Button(L10n.Growth.removePhoto, systemImage: "trash", action: clearPhoto)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text(L10n.Growth.addPhoto)
                        .font(.headingXS)
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    private func clearPhoto() {
        photo = nil
        removePhoto = true
        didPickNewPhoto = false
    }

    private func openHeightPicker() {
        activeWheel = .height
    }

    private func openWeightPicker() {
        activeWheel = .weight
    }

    private var dateFieldRow: some View {
        HStack {
            Text(L10n.Growth.date)
                .font(.bodyL)
                .foregroundStyle(Color.textPrimary)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            DatePicker(
                L10n.Growth.date,
                selection: $date,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func measurementFieldRow(
        title: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.bodyL)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Text(value)
                        .font(.statLabel)
                        .foregroundStyle(Color.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func fieldSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)

            content()
                .font(.bodyL)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private var canSave: Bool {
        GrowthEntry.parseHeightCm(heightLabel) != nil
            && GrowthEntry.parseWeightKg(weightLabel) != nil
    }

    private func persist() {
        guard let heightCm = GrowthEntry.parseHeightCm(heightLabel),
              let weightKg = GrowthEntry.parseWeightKg(weightLabel) else { return }
        let entry = GrowthEntry(
            id: existing?.id ?? UUID(),
            date: date,
            heightCm: heightCm,
            weightKg: weightKg,
            photoFilename: existing?.photoFilename,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(entry, didPickNewPhoto ? photo : nil, removePhoto)
        dismiss()
    }
}
