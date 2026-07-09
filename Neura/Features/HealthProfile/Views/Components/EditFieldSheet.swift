import SwiftUI
import UIKit

struct EditFieldSheet: View {
    let fieldName: String
    let keyboardType: UIKeyboardType
    @State private var value: String
    let onSave: (String) -> Void
    let onDelete: (() -> Void)?
    /// Optional format check run on save (e.g. email). Skipped when the trimmed
    /// value is empty, so clearing a field never triggers a validation error.
    let validate: ((String) -> Bool)?
    let invalidMessage: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var showError = false

    init(fieldName: String, value: String, keyboardType: UIKeyboardType = .default, validate: ((String) -> Bool)? = nil, invalidMessage: String? = nil, onDelete: (() -> Void)? = nil, onSave: @escaping (String) -> Void) {
        self.fieldName = fieldName
        self.keyboardType = keyboardType
        self._value = State(initialValue: value)
        self.validate = validate
        self.invalidMessage = invalidMessage
        self.onDelete = onDelete
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceWhite)
                            .clipShape(Circle())
                    }
                }

                Spacer()
                Button {
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    if let validate, !trimmed.isEmpty, !validate(trimmed) {
                        showError = true
                        return
                    }
                    onSave(trimmed)
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
                    .font(.BodyML)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardType(keyboardType)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.surfaceWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .focused($isFocused)
                    .onChange(of: value) { _, _ in showError = false }

                if showError, let invalidMessage {
                    Text(invalidMessage)
                        .font(.captionS)
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.backgroundPrimary)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
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
