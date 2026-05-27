import SwiftUI

struct WheelPickerSheet: View {
    let fieldName: String
    let values: [String]
    @State private var selectedIndex: Int
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        fieldName: String,
        values: [String],
        current: String,
        onSave: @escaping (String) -> Void
    ) {
        self.fieldName = fieldName
        self.values = values
        let startIndex = values.firstIndex(of: current) ?? (values.count / 2)
        self._selectedIndex = State(initialValue: startIndex)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button {
                    onSave(values[selectedIndex])
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accent)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.HealthProfile.editFormat(fieldName))
                    .font(.displayXL)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 20)

                // Selected value display
                Text(values[selectedIndex])
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.accent)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedIndex)

                // Wheel picker
                Picker("", selection: $selectedIndex) {
                    ForEach(values.indices, id: \.self) { i in
                        Text(values[i])
                            .font(.system(size: 18))
                            .tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                .padding(.horizontal, 20)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 20))
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Preset Value Ranges

extension WheelPickerSheet {
    static var heightValues: [String] {
        (100...230).map { "\($0) cm" }
    }

    static var weightValues: [String] {
        (30...200).map { "\($0) kg" }
    }
}

#Preview {
    WheelPickerSheet(
        fieldName: "Height",
        values: WheelPickerSheet.heightValues,
        current: "170 cm"
    ) { _ in }
}
