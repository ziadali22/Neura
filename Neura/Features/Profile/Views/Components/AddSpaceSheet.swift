import SwiftUI
import PhotosUI

struct NewAccountDetails {
    var relationship: String?
    var dateOfBirth: String?
    var gender: String?
    var bloodType: String?
    var height: String?
    var weight: String?
}

struct AddSpaceSheet: View {
    enum Mode {
        case create
        case edit(Space)
    }

    private struct IdentifiableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    static let bloodTypeOptions = ["A+", "A−", "B+", "B−", "AB+", "AB−", "O+", "O−"]

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var avatarImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imagePendingCrop: IdentifiableImage?

    // Additional questions asked only when creating a brand-new account.
    @State private var relationship: Space.Relationship
    @State private var includeDateOfBirth = false
    @State private var dateOfBirth = Date()
    @State private var gender = ""
    @State private var bloodType = ""
    @State private var height = ""
    @State private var weight = ""

    private let mode: Mode
    private let existingColorHex: String?
    let onSave: (String, UIImage?, NewAccountDetails) -> Void

    init(mode: Mode = .create, onSave: @escaping (String, UIImage?, NewAccountDetails) -> Void) {
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
        _relationship = State(initialValue: .child)
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

                if case .create = mode {
                    Section(L10n.Profile.Spaces.detailsSectionTitle) {
                        Picker(L10n.Profile.Spaces.relationshipLabel, selection: $relationship) {
                            ForEach(Space.Relationship.allCases) { option in
                                Text(option.localizedTitle).tag(option)
                            }
                        }

                        Toggle(L10n.Profile.Spaces.includeDateOfBirth, isOn: $includeDateOfBirth.animation())
                        if includeDateOfBirth {
                            DatePicker(
                                L10n.HealthProfile.dateOfBirth,
                                selection: $dateOfBirth,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                        }

                        Picker(L10n.HealthProfile.gender, selection: $gender) {
                            Text(L10n.Common.notSet).tag("")
                            Text(HealthOption.localized("Male")).tag("Male")
                            Text(HealthOption.localized("Female")).tag("Female")
                            Text(HealthOption.localized("Prefer not to say")).tag("Prefer not to say")
                        }

                        Picker(L10n.HealthProfile.bloodType, selection: $bloodType) {
                            Text(L10n.Common.notSet).tag("")
                            ForEach(Self.bloodTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }

                        Picker(L10n.HealthProfile.height, selection: $height) {
                            Text(L10n.Common.notSet).tag("")
                            ForEach(WheelPickerSheet.heightValues, id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }

                        Picker(L10n.HealthProfile.weight, selection: $weight) {
                            Text(L10n.Common.notSet).tag("")
                            ForEach(WheelPickerSheet.weightValues, id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                    }
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
                        onSave(trimmed, avatarImage, collectedDetails)
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

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private var collectedDetails: NewAccountDetails {
        guard case .create = mode else { return NewAccountDetails() }
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        return NewAccountDetails(
            relationship: relationship.rawValue,
            dateOfBirth: includeDateOfBirth ? "\(Self.dobFormatter.string(from: dateOfBirth)) (\(age))" : nil,
            gender: gender.isEmpty ? nil : gender,
            bloodType: bloodType.isEmpty ? nil : bloodType,
            height: height.isEmpty ? nil : height,
            weight: weight.isEmpty ? nil : weight
        )
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
