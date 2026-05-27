import SwiftUI
import UIKit

struct EditFieldSheet: View {
    let fieldName: String
    let keyboardType: UIKeyboardType
    @State private var value: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    init(fieldName: String, value: String, keyboardType: UIKeyboardType = .default, onSave: @escaping (String) -> Void) {
        self.fieldName = fieldName
        self.keyboardType = keyboardType
        self._value = State(initialValue: value)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    onSave(value.trimmingCharacters(in: .whitespaces))
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

            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.HealthProfile.editFormat(fieldName))
                    .font(.displayXL)
                    .foregroundStyle(Color.textPrimary)

                TextField(fieldName, text: $value)
                    .font(.bodyL)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardType(keyboardType)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.surfaceWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .focused($isFocused)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

#Preview {
    EditFieldSheet(fieldName: "Name", value: "Elena Rossi") { newValue in
        print("Saved: \(newValue)")
    }
}
