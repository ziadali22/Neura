import SwiftUI

struct EmailCaptureRow: View {
    let onSave: (String) -> Void

    @State private var email: String
    @State private var savedEmail: String
    @FocusState private var isFocused: Bool
    @State private var showError = false

    init(initialEmail: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _email = State(initialValue: initialEmail)
        _savedEmail = State(initialValue: initialEmail)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidFormat: Bool {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return trimmedEmail.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private var hasChanges: Bool { trimmedEmail != savedEmail }
    private var canSave: Bool { isValidFormat && hasChanges }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 24, height: 24)

                TextField(L10n.Profile.emailPlaceholder, text: $email)
                    .font(.statLabel)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .onChange(of: email) { _, _ in showError = false }

                Spacer()

                Button {
                    isFocused = false
                    guard hasChanges else { return }
                    guard isValidFormat else {
                        showError = true
                        return
                    }
                    showError = false
                    savedEmail = trimmedEmail
                    onSave(trimmedEmail)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(canSave ? Color.accent : Color.textTertiary)
                }
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)

            if showError {
                Text(L10n.Profile.emailInvalid)
                    .font(.captionS)
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 4)
            }
        }
    }
}

#Preview {
    VStack(spacing: 11) {
        EmailCaptureRow(initialEmail: "") { email in
            print("saved: \(email)")
        }
        EmailCaptureRow(initialEmail: "existing@example.com") { email in
            print("saved: \(email)")
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
