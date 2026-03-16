import SwiftUI

struct GeneralDataSheet: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingField: GeneralFieldInfo?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.textPrimary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("General Data")
                        .font(.displayXL)
                        .foregroundColor(.textPrimary)
                        .padding(.bottom, 8)

                    ForEach(fields) { field in
                        fieldRow(field)
                    }

                    addFieldButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color.backgroundPrimary)
        .sheet(item: $editingField) { field in
            EditFieldSheet(
                fieldName: field.label,
                value: field.value
            ) { newValue in
                viewModel.updateGeneralField(field.keyPath, value: newValue)
            }
            .presentationDragIndicator(.hidden)
        }
    }

    private var fields: [GeneralFieldInfo] {
        let data = viewModel.profile.generalData
        return [
            .init(label: "Name", keyPath: \.fullName, value: data.fullName),
            .init(label: "Date of birth", keyPath: \.dateOfBirth, value: data.dateOfBirth),
            .init(label: "Gender", keyPath: \.gender, value: data.gender),
            .init(label: "Height", keyPath: \.height, value: data.height),
            .init(label: "Weight", keyPath: \.weight, value: data.weight),
            .init(label: "Insurance Status", keyPath: \.insuranceStatus, value: data.insuranceStatus),
            .init(label: "Blood Type", keyPath: \.bloodType, value: data.bloodType),
        ]
    }
}

// MARK: - Subviews

private extension GeneralDataSheet {
    func fieldRow(_ field: GeneralFieldInfo) -> some View {
        Button {
            editingField = field
        } label: {
            HStack {
                Text(field.label)
                    .font(.bodyL)
                    .foregroundColor(.textPrimary)

                Spacer()

                if field.value.isEmpty {
                    HStack(spacing: 4) {
                        Text("Add")
                            .font(.bodyL)
                            .foregroundColor(.textTertiary)
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundColor(.textTertiary)
                    }
                } else {
                    Text(field.value)
                        .font(.bodyL)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var addFieldButton: some View {
        Button {
            // TODO: Support custom general data fields
        } label: {
            HStack {
                Text("Add Field")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Field Info

struct GeneralFieldInfo: Identifiable {
    var id: String { label }
    let label: String
    let keyPath: WritableKeyPath<HealthProfile.GeneralData, String>
    let value: String
}

#Preview {
    GeneralDataSheet(viewModel: HealthProfileViewModel())
}
