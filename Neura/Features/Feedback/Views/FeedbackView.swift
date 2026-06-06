import SwiftUI

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedbackViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, message
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    fieldGroup(
                        label: L10n.Profile.Feedback.emailLabel
                    ) { emailField }

                    fieldGroup(
                        label: L10n.Profile.Feedback.messageLabel
                    ) { messageField }

                    if case let .error(message) = viewModel.state {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }

                    submitButton
                }
                .padding(20)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(L10n.Profile.Feedback.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                guard newState == .success else { return }
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Subviews

private extension FeedbackView {

    func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
            content()
                .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: -4)
        }
    }

    var emailField: some View {
        TextField(L10n.Profile.Feedback.emailPlaceholder, text: $viewModel.email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .email)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .cornerRadius(14)
    }

    var messageField: some View {
        TextField(
            L10n.Profile.Feedback.messagePlaceholder,
            text: $viewModel.message,
            axis: .vertical
        )
        .lineLimit(5...10)
        .focused($focusedField, equals: .message)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceWhite)
        .cornerRadius(14)
    }

    var submitButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.submit() }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView().tint(.white)
                } else if viewModel.state == .success {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                } else {
                    Text(L10n.Profile.Feedback.submit)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isValid ? Color.accent : Color.accent.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!viewModel.isValid || viewModel.isSubmitting || viewModel.state == .success)
    }
}

#Preview {
    FeedbackView()
}
