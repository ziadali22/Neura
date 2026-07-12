import SwiftUI
import PhotosUI

struct AddSpaceSheet: View {
    enum Mode {
        case create
        case edit(Space)
    }

    private struct IdentifiableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var avatarImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imagePendingCrop: IdentifiableImage?

    private let mode: Mode
    private let existingColorHex: String?
    let onSave: (String, UIImage?) -> Void

    init(mode: Mode = .create, onSave: @escaping (String, UIImage?) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _avatarImage = State(initialValue: nil)
            existingColorHex = nil
        case .edit(let space):
            _name = State(initialValue: space.name)
            _avatarImage = State(initialValue: space.avatarFilename.flatMap { AccountAvatarStore.shared.loadImage(filename: $0) })
            existingColorHex = space.colorHex
        }
    }

    private var title: String {
        switch mode {
        case .create: return L10n.Profile.Spaces.addSpaceTitle
        case .edit: return L10n.Profile.Spaces.editSpaceTitle
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            avatarPreview
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(L10n.Profile.Spaces.namePlaceholder, text: $name)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, avatarImage)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
        .fullScreenCover(item: $imagePendingCrop) { wrapped in
            AvatarCropView(
                image: wrapped.image,
                onCancel: { imagePendingCrop = nil },
                onConfirm: { cropped in
                    avatarImage = cropped
                    imagePendingCrop = nil
                }
            )
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: existingColorHex ?? "D8D2CB"))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                )
        }
    }
}
