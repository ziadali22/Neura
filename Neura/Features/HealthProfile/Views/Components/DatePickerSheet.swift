import SwiftUI

struct DatePickerSheet: View {
    let fieldName: String
    @State private var selectedDate: Date
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    init(fieldName: String, current: String, onSave: @escaping (String) -> Void) {
        self.fieldName = fieldName
        self.onSave = onSave
        // Strip the age suffix "(24)" if present before parsing
        let stripped = current
            .replacingOccurrences(of: #"\s*\(\d+\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let parsed = Self.displayFormatter.date(from: stripped) ?? Date()
        self._selectedDate = State(initialValue: parsed)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button {
                    onSave(formattedValue)
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
                VStack(spacing: 2) {
                    Text(Self.displayFormatter.string(from: selectedDate))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.accent)
                        .contentTransition(.numericText())

                    Text("\(age) years old")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedDate)

                // Date picker
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
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

    // MARK: - Helpers

    private var age: Int {
        Calendar.current.dateComponents([.year], from: selectedDate, to: Date()).year ?? 0
    }

    private var formattedValue: String {
        "\(Self.displayFormatter.string(from: selectedDate)) (\(age))"
    }
}

#Preview {
    DatePickerSheet(fieldName: "Date of birth", current: "02 Jan 2002 (24)") { _ in }
}
