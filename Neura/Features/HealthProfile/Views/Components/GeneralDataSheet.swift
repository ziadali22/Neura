import SwiftUI

struct GeneralDataSheet: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    @Environment(\.dismiss) private var dismiss

    // Active sheets
    @State private var textEditingField: GeneralFieldInfo?
    @State private var datePickerField: GeneralFieldInfo?
    @State private var optionPickerField: GeneralFieldInfo?
    @State private var wheelPickerField: GeneralFieldInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
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
        // Text input sheet (Name only)
        .sheet(item: $textEditingField) { field in
            EditFieldSheet(fieldName: field.label, value: field.value) { newValue in
                viewModel.updateGeneralField(field.keyPath, value: newValue)
            }
            .presentationDragIndicator(.hidden)
        }
        // Date picker sheet (Date of Birth)
        .sheet(item: $datePickerField) { field in
            DatePickerSheet(fieldName: field.label, current: field.value) { newValue in
                viewModel.updateGeneralField(field.keyPath, value: newValue)
            }
            .presentationDragIndicator(.hidden)
        }
        // Option picker sheet (Gender, Blood Type, Insurance)
        .sheet(item: $optionPickerField) { field in
            OptionPickerSheet(
                fieldName: field.label,
                options: field.options,
                current: field.value
            ) { newValue in
                viewModel.updateGeneralField(field.keyPath, value: newValue)
            }
            .presentationDragIndicator(.hidden)
        }
        // Wheel picker sheet (Height, Weight)
        .sheet(item: $wheelPickerField) { field in
            WheelPickerSheet(
                fieldName: field.label,
                values: field.wheelValues,
                current: field.value
            ) { newValue in
                viewModel.updateGeneralField(field.keyPath, value: newValue)
            }
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Fields

    private var fields: [GeneralFieldInfo] {
        let data = viewModel.profile.generalData
        return [
            .init(label: "Name",             keyPath: \.fullName,        value: data.fullName,        kind: .text),
            .init(label: "Date of birth",    keyPath: \.dateOfBirth,     value: data.dateOfBirth,     kind: .date),
            .init(label: "Gender",           keyPath: \.gender,          value: data.gender,          kind: .options(["Male", "Female", "Prefer not to say"])),
            .init(label: "Height",           keyPath: \.height,          value: data.height,          kind: .wheel(WheelPickerSheet.heightValues)),
            .init(label: "Weight",           keyPath: \.weight,          value: data.weight,          kind: .wheel(WheelPickerSheet.weightValues)),
            .init(label: "Insurance Status",  keyPath: \.insuranceStatus,  value: data.insuranceStatus,  kind: .options(["Insured", "Uninsured", "Partially Insured"])),
            .init(label: "Blood Type",        keyPath: \.bloodType,        value: data.bloodType,        kind: .options(["A+", "A−", "B+", "B−", "AB+", "AB−", "O+", "O−"])),
            .init(label: "Emergency Contact", keyPath: \.emergencyContact, value: data.emergencyContact, kind: .text),
        ]
    }
}

// MARK: - Subviews

private extension GeneralDataSheet {
    func fieldRow(_ field: GeneralFieldInfo) -> some View {
        Button { open(field) } label: {
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
                    HStack(spacing: 6) {
                        Text(field.value)
                            .font(.statLabel)
                            .foregroundColor(.textSecondary)
                        if field.kind != .text {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func open(_ field: GeneralFieldInfo) {
        switch field.kind {
        case .text:
            textEditingField = field
        case .date:
            datePickerField = field
        case .options:
            optionPickerField = field
        case .wheel:
            wheelPickerField = field
        }
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

enum GeneralFieldKind: Equatable {
    case text
    case date
    case options([String])
    case wheel([String])
}

struct GeneralFieldInfo: Identifiable {
    var id: String { label }
    let label: String
    let keyPath: WritableKeyPath<HealthProfile.GeneralData, String>
    let value: String
    let kind: GeneralFieldKind

    var options: [String] {
        if case .options(let opts) = kind { return opts }
        return []
    }

    var wheelValues: [String] {
        if case .wheel(let vals) = kind { return vals }
        return []
    }
}

#Preview {
    GeneralDataSheet(viewModel: HealthProfileViewModel())
}
