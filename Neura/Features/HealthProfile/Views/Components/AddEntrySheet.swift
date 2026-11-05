import SwiftUI

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let config: SectionFieldConfig
    let existingEntry: HealthProfile.HealthSection.Entry?
    let onSave: (String, String, String, String) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String = ""
    @State private var field1: String = ""
    @State private var field1Date: Date = Date()
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
        _field1Date = State(initialValue: Self.parseDate(entry?.field1) ?? Date())
        _field2 = State(initialValue: entry?.field2 ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return dateFormatter.date(from: value)
    }

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        fieldSection(config.nameLabel) {
                            TextField(config.namePlaceholder, text: $name)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = config.field1IsDate ? .field2 : .field1 }
                        }
                        .id(Field.name)

                        fieldSection(config.field1Label) {
                            if config.field1IsDate {
                                DatePicker(
                                    config.field1Label,
                                    selection: $field1Date,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                TextField(config.field1Placeholder, text: $field1)
                                    .focused($focusedField, equals: .field1)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .field2 }
                            }
                        }
                        .id(Field.field1)

                        fieldSection(config.field2Label) {
                            TextField(config.field2Placeholder, text: $field2)
                                .focused($focusedField, equals: .field2)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .notes }
                        }
                        .id(Field.field2)

                        fieldSection(L10n.HealthProfile.notesOptional) {
                            TextField(L10n.HealthProfile.additionalDetails, text: $notes)
                                .focused($focusedField, equals: .notes)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                        }
                        .id(Field.notes)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    scrollToField(field, proxy: proxy)
                }
                .onChange(of: notes) { _, _ in
                    guard focusedField == .notes else { return }
                    scrollToField(.notes, proxy: proxy)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if existingEntry != nil, onDelete != nil {
                deleteButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.backgroundPrimary)
        .alert(L10n.Common.areYouSure, isPresented: $showDeleteConfirmation) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text(L10n.Common.thisActionCannotBeUndone)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField = .name
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(config.addTitle)
                .font(.buttonL)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 112)

            HStack {
                Button {
                    focusedField = nil
                    dismiss()
                } label: {
                    Text(L10n.Common.cancel)
                        .font(.bodyL)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.surfaceWhite)
                        .frame(width: 40, height: 40)
                        .background(canSave ? Color.accent : Color.textTertiary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityLabel(L10n.Common.done)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text(config.deleteTitle)
                    .font(.bodyL)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Helpers

    private func scrollToField(_ field: Field, proxy: ScrollViewProxy) {
        let anchor: UnitPoint = field == .notes ? .bottom : .center
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(field, anchor: anchor)
        }
    }

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
        let resolvedField1 = config.field1IsDate
            ? Self.dateFormatter.string(from: field1Date)
            : field1.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            resolvedField1,
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
