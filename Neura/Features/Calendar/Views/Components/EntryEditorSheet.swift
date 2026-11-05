import SwiftUI

/// Create or edit a calendar entry. `entry == nil` means create.
struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: CalendarEntry?
    let initialDate: Date
    let onSave: (CalendarEntry) -> Void
    let onDelete: ((CalendarEntry) -> Void)?
    let onDeleteDocument: ((Document) -> Void)?
    let onUpdateDocument: ((Document, DocumentMetadata, DocumentPreviewContent) -> Void)?

    @State private var type: CalendarEntryType
    @State private var title: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var frequency: RecurrenceFrequency
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String
    @State private var documents: [Document]
    @State private var linkedDocumentID: UUID?
    @State private var viewingDocument: Document?
    @State private var doctor: String
    @State private var specialization: MedicalSpecialization?
    @State private var showDeleteConfirm = false

    @FocusState private var focusedField: Field?

    private enum Field { case title, doctor, notes }

    init(
        existing: CalendarEntry?,
        initialDate: Date,
        documents: [Document],
        onSave: @escaping (CalendarEntry) -> Void,
        onDelete: ((CalendarEntry) -> Void)? = nil,
        onDeleteDocument: ((Document) -> Void)? = nil,
        onCreateDocument _: @escaping (Document) -> Void = { _ in },
        onUpdateDocument: ((Document, DocumentMetadata, DocumentPreviewContent) -> Void)? = nil
    ) {
        self.existing = existing
        self.initialDate = initialDate
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDeleteDocument = onDeleteDocument
        self.onUpdateDocument = onUpdateDocument

        _type = State(initialValue: existing?.type ?? .medication)
        _title = State(initialValue: existing?.title ?? "")
        _date = State(initialValue: existing?.date ?? initialDate)
        _isAllDay = State(initialValue: existing?.isAllDay ?? false)
        _frequency = State(initialValue: existing?.recurrence.frequency ?? .none)
        _hasEndDate = State(initialValue: existing?.recurrence.endDate != nil)
        _endDate = State(initialValue: existing?.recurrence.endDate ?? initialDate)
        _notes = State(initialValue: existing?.notes ?? "")
        _documents = State(initialValue: documents)
        _linkedDocumentID = State(initialValue: Self.resolvedDocumentID(existing: existing))
        _doctor = State(initialValue: existing?.doctor ?? "")
        _specialization = State(initialValue: existing?.specialization)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.Calendar.fieldType, selection: $type) {
                        ForEach(CalendarEntryType.allCases) { t in
                            Text(t.localizedName).tag(t)
                        }
                    }
                    TextField(L10n.Calendar.fieldTitlePlaceholder, text: $title)
                        .focused($focusedField, equals: .title)
                }

                Section {
                    Picker(L10n.Calendar.fieldSpecialization, selection: $specialization) {
                        Text(L10n.Calendar.noDocumentLinked).tag(MedicalSpecialization?.none)
                        ForEach(MedicalSpecialization.allCases) { spec in
                            Text(spec.localizedName).tag(MedicalSpecialization?.some(spec))
                        }
                    }
                    TextField(L10n.Calendar.fieldDoctorPlaceholder, text: $doctor)
                        .focused($focusedField, equals: .doctor)
                }

                Section {
                    Toggle(L10n.Calendar.fieldAllDay, isOn: $isAllDay)
                    DatePicker(L10n.Calendar.fieldDate, selection: $date, displayedComponents: .date)
                    if !isAllDay {
                        DatePicker(L10n.Calendar.fieldTime, selection: $date, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "en_GB"))
                    }
                    Picker(L10n.Calendar.fieldRepeat, selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { f in
                            Text(f.localizedName).tag(f)
                        }
                    }
                    if frequency != .none {
                        Toggle(L10n.Calendar.fieldEndDate, isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker(L10n.Calendar.fieldEndDate, selection: $endDate, displayedComponents: .date)
                        }
                    }
                }

                Section {
                    Label(reminderInfoText, systemImage: "bell.fill")
                        .font(.captionS)
                        .foregroundStyle(Color.textSecondary)
                }

                Section {
                    Picker(L10n.Calendar.fieldLinkDocument, selection: $linkedDocumentID) {
                        Text(L10n.Calendar.noDocumentLinked).tag(UUID?.none)
                        if let linkedDocumentID, !linkableDocuments.contains(where: { $0.id == linkedDocumentID }) {
                            Text(L10n.Calendar.attachmentMissing).tag(UUID?.some(linkedDocumentID))
                        }
                        ForEach(linkableDocuments) { document in
                            Text(document.name).tag(UUID?.some(document.id))
                        }
                    }

                    if linkedDocument != nil {
                        Button(L10n.Calendar.openDocument, systemImage: "doc", action: openLinkedDocument)
                    }
                }

                Section(L10n.Calendar.fieldNotes) {
                    TextField(L10n.Calendar.fieldNotes, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                }

                if existing != nil, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            focusedField = nil
                            showDeleteConfirm = true
                        } label: {
                            Text(L10n.Calendar.deleteEntry)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            // Tap anywhere to dismiss the keyboard. Uses a window-level recognizer
            // (see KeyboardDismiss.swift) instead of a gesture on the Form — a Form
            // gesture, even `.simultaneousGesture`, swallows taps to Pickers and
            // NavigationLinks (Type, Specialization, Link document never open).
            .dismissKeyboardOnTap()
            // Centered confirmation alert.
            .alert(L10n.Calendar.deleteConfirmTitle, isPresented: $showDeleteConfirm) {
                Button(L10n.Calendar.deleteEntry, role: .destructive) {
                    if let existing, let onDelete {
                        onDelete(existing)
                        dismiss()
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Calendar.deleteConfirmMessage)
            }
            .sheet(item: $viewingDocument) { document in
                NavigationStack {
                    DocumentViewerView(
                        document: document,
                        onDelete: { removeLinkedDocument(document) },
                        onEdit: { metadata, preview in
                            applyLinkedDocumentEdit(document, metadata: metadata, preview: preview)
                        }
                    )
                }
            }
            .navigationTitle(existing == nil ? L10n.Calendar.newEntryTitle : L10n.Calendar.editEntryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { saveAndDismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var reminderInfoText: String {
        let recurring = frequency != .none
        switch type {
        case .appointment:
            return recurring ? L10n.Calendar.reminderInfoAppointmentRecurring : L10n.Calendar.reminderInfoAppointment
        case .medication:
            return recurring ? L10n.Calendar.reminderInfoMedicationRecurring : L10n.Calendar.reminderInfoMedication
        case .medicalEvent:
            return recurring ? L10n.Calendar.reminderInfoMedicalEventRecurring : L10n.Calendar.reminderInfoMedicalEvent
        }
    }

    private func saveAndDismiss() {
        let recurrence = RecurrenceRule(
            frequency: frequency,
            endDate: (frequency != .none && hasEndDate) ? endDate : nil
        )
        let trimmedDoctor = doctor.trimmingCharacters(in: .whitespaces)
        // All-day entries carry no meaningful time, so snap to 9 AM. This keeps
        // reminder lead-times (which subtract from the entry date) firing in the
        // morning-of rather than late the night before from a midnight date.
        let resolvedDate = isAllDay ? Self.allDayTime(for: date) : date
        let entry = CalendarEntry(
            id: existing?.id ?? UUID(),
            type: type,
            title: title.trimmingCharacters(in: .whitespaces),
            date: resolvedDate,
            isAllDay: isAllDay,
            notes: notes.isEmpty ? nil : notes,
            linkedDocumentID: linkedDocumentID,
            imageAttachmentID: nil,
            documentAttachmentID: linkedDocumentID,
            prescriptionAttachmentID: nil,
            reminder: existing?.reminder,
            recurrence: recurrence,
            doctor: trimmedDoctor.isEmpty ? nil : trimmedDoctor,
            specialization: specialization,
            completedDates: existing?.completedDates ?? [],
            spaceID: existing?.spaceID
        )
        onSave(entry)
        dismiss()
    }

    /// The file currently chosen in "Link a document", when it still exists in Docs.
    private var linkedDocument: Document? {
        guard let linkedDocumentID else { return nil }
        return documents.first { $0.id == linkedDocumentID }
    }

    private func openLinkedDocument() {
        viewingDocument = linkedDocument
    }

    /// Unlink first so a deleted file is not saved back onto the entry.
    /// The viewer dismisses itself after this returns.
    private func removeLinkedDocument(_ document: Document) {
        if linkedDocumentID == document.id {
            linkedDocumentID = nil
        }
        onDeleteDocument?(document)
    }

    private func applyLinkedDocumentEdit(
        _ document: Document,
        metadata: DocumentMetadata,
        preview: DocumentPreviewContent
    ) {
        onUpdateDocument?(document, metadata, preview)
        let trimmed = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].name = trimmed
    }

    /// Newest first. The menu shows the same saved files as Docs.
    private var linkableDocuments: [Document] {
        documents.sorted { $0.createdAt > $1.createdAt }
    }

    /// One linked file. Older entries may have stored it on any attachment slot.
    private static func resolvedDocumentID(existing: CalendarEntry?) -> UUID? {
        guard let existing else { return nil }
        return existing.documentAttachmentID
            ?? existing.linkedDocumentID
            ?? existing.prescriptionAttachmentID
            ?? existing.imageAttachmentID
    }

    /// 9 AM on the same calendar day as `date`.
    private static func allDayTime(for date: Date) -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }
}
