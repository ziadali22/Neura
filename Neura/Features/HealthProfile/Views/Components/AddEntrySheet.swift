import SwiftUI

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let config: SectionFieldConfig
    let existingEntry: HealthProfile.HealthSection.Entry?
    let onSave: (String, String, String, String) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String = ""
    @State private var field1: String = ""
    @State private var field2: String = ""
    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, field1, field2, notes
    }

    init(
        config: SectionFieldConfig,
        entry: HealthProfile.HealthSection.Entry? = nil,
        onSave: @escaping (String, String, String, String) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.config = config
        self.existingEntry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: entry?.text ?? "")
        _field1 = State(initialValue: entry?.field1 ?? "")
        _field2 = State(initialValue: entry?.field2 ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    fieldSection(config.nameLabel) {
                        TextField(config.namePlaceholder, text: $name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .field1 }
                    }

                    fieldSection(config.field1Label) {
                        TextField(config.field1Placeholder, text: $field1)
                            .focused($focusedField, equals: .field1)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .field2 }
                    }

                    fieldSection(config.field2Label) {
                        TextField(config.field2Placeholder, text: $field2)
                            .focused($focusedField, equals: .field2)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                    }

                    fieldSection("Notes (Optional)") {
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Additional details")
                                    .font(.bodyL)
                                    .foregroundColor(.textTertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $notes)
                                .font(.bodyL)
                                .focused($focusedField, equals: .notes)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                        }
                    }

                    if existingEntry != nil, let onDelete {
                        Spacer().frame(height: 20)

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                Text("Delete \(config.addTitle.replacingOccurrences(of: "Add ", with: ""))")
                                    .font(.bodyL)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .background(Color.backgroundPrimary)
            .navigationTitle(existingEntry != nil ? config.addTitle : config.addTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(canSave ? Color.accent : Color.textTertiary)
                            .clipShape(Circle())
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .fontWeight(.medium)
                    }
                }
            }
            .alert("Are you sure?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    focusedField = .name
                }
            }
        }
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headingXS)
                .foregroundColor(.textPrimary)

            content()
                .font(.bodyL)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.surfaceWhite)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard canSave else { return }
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSave(
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            field1.trimmingCharacters(in: .whitespacesAndNewlines),
            field2.trimmingCharacters(in: .whitespacesAndNewlines),
            notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}

#Preview {
    AddEntrySheet(
        config: .forSection("Allergies"),
        onSave: { _, _, _, _ in }
    )
}
