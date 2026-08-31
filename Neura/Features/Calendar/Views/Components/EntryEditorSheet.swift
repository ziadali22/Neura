import SwiftUI

/// Create or edit a calendar entry. `entry == nil` means create.
struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: CalendarEntry?
    let initialDate: Date
    let documents: [Document]
    let onSave: (CalendarEntry) -> Void
    let onDelete: ((CalendarEntry) -> Void)?
    let onDeleteDocument: ((Document) -> Void)?

    @State private var type: CalendarEntryType
    @State private var title: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var frequency: RecurrenceFrequency
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String
    @State private var linkedDocumentID: UUID?
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
        onDeleteDocument: ((Document) -> Void)? = nil
    ) {
        self.existing = existing
        self.initialDate = initialDate
        self.documents = documents
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDeleteDocument = onDeleteDocument

        _type = State(initialValue: existing?.type ?? .medication)
        _title = State(initialValue: existing?.title ?? "")
        _date = State(initialValue: existing?.date ?? initialDate)
        _isAllDay = State(initialValue: existing?.isAllDay ?? false)
        _frequency = State(initialValue: existing?.recurrence.frequency ?? .none)
        _hasEndDate = State(initialValue: existing?.recurrence.endDate != nil)
        _endDate = State(initialValue: existing?.recurrence.endDate ?? initialDate)
        _notes = State(initialValue: existing?.notes ?? "")
        _linkedDocumentID = State(initialValue: existing?.linkedDocumentID)
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
                        ForEach(documents) { doc in
                            Text(doc.name).tag(UUID?.some(doc.id))
                        }
                    }
                    if let id = linkedDocumentID, let doc = documents.first(where: { $0.id == id }) {
                        NavigationLink {
                            DocumentViewerView(document: doc, onDelete: {
                                onDeleteDocument?(doc)
                                linkedDocumentID = nil
                            })
                            .toolbar(.hidden, for: .navigationBar)
                        } label: {
                            Label(L10n.Calendar.openDocument, systemImage: "doc.text")
                        }
                        Button(role: .destructive) {
                            linkedDocumentID = nil
                        } label: {
                            Label(L10n.Calendar.removeLinkedDocument, systemImage: "link.badge.minus")
                        }
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
            recurrence: recurrence,
            doctor: trimmedDoctor.isEmpty ? nil : trimmedDoctor,
            specialization: specialization,
            completedDates: existing?.completedDates ?? []
        )
        onSave(entry)
        dismiss()
    }

    /// 9 AM on the same calendar day as `date`.
    private static func allDayTime(for date: Date) -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }
}
