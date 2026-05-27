import SwiftUI

struct OptionPickerSheet: View {
    let fieldName: String
    let options: [String]
    @State private var selected: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        fieldName: String,
        options: [String],
        current: String,
        onSave: @escaping (String) -> Void
    ) {
        self.fieldName = fieldName
        self.options = options
        self._selected = State(initialValue: current)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button {
                    onSave(selected)
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.HealthProfile.editFormat(fieldName))
                        .font(.displayXL)
                        .foregroundStyle(Color.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selected = option
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.bodyL)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if selected == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.accent)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(selected == option ? Color.accent.opacity(0.08) : Color.surfaceWhite)
                                .clipShape(.rect(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            selected == option ? Color.accent.opacity(0.3) : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color.backgroundPrimary)
    }
}

#Preview {
    OptionPickerSheet(
        fieldName: "Gender",
        options: ["Male", "Female", "Non-binary", "Other", "Prefer not to say"],
        current: "Female"
    ) { _ in }
}
