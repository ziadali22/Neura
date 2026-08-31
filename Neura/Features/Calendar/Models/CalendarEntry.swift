import SwiftUI
import L10n_swift

// MARK: - Entry Type

enum CalendarEntryType: String, Codable, CaseIterable, Identifiable {
    case medication   = "Medication"
    case appointment  = "Appointment"
    case medicalEvent = "Medical Event"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .medication:   return "calendar.entryType.medication".l10n()
        case .appointment:  return "calendar.entryType.appointment".l10n()
        case .medicalEvent: return "calendar.entryType.medicalEvent".l10n()
        }
    }

    /// Custom asset name, rendered as a template image tinted with `color`.
    var icon: String {
        switch self {
        case .medication:   return "calendar-medicine"
        case .appointment:  return "calendar-events"
        case .medicalEvent: return "calendar-events"
        }
    }

    var color: Color {
        switch self {
        case .medication:   return .accent              // orange
        case .appointment:  return .textPrimary         // black
        case .medicalEvent: return Color(hex: "E74C3C") // red
        }
    }
}

// MARK: - Recurrence

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .none:    return "calendar.recurrence.none".l10n()
        case .daily:   return "calendar.recurrence.daily".l10n()
        case .weekly:  return "calendar.recurrence.weekly".l10n()
        case .monthly: return "calendar.recurrence.monthly".l10n()
        }
    }
}

struct RecurrenceRule: Codable, Equatable {
    var frequency: RecurrenceFrequency = .none
    var endDate: Date? = nil

    /// Concrete occurrence dates within `range`, starting from `start`.
    /// Times are carried from `start`. Hard-capped to avoid runaway loops.
    func occurrences(in range: ClosedRange<Date>, from start: Date) -> [Date] {
        let cal = Calendar.current
        guard frequency != .none else {
            return range.contains(start) ? [start] : []
        }
        let component: Calendar.Component
        switch frequency {
        case .daily:   component = .day
        case .weekly:  component = .weekOfYear
        case .monthly: component = .month
        case .none:    return []
        }
        var result: [Date] = []
        var current = start
        var guardCount = 0
        while current <= range.upperBound && guardCount < 10_000 {
            if let end = endDate, current > end { break }
            if current >= range.lowerBound {
                result.append(current)
            }
            guard let next = cal.date(byAdding: component, value: 1, to: current) else { break }
            current = next
            guardCount += 1
        }
        return result
    }
}

// MARK: - Reminder

enum ReminderLead: String, Codable, CaseIterable, Identifiable {
    case atTime, minutes15, hour1, day1
    var id: String { rawValue }

    /// Seconds BEFORE the occurrence the notification should fire.
    var secondsBefore: TimeInterval {
        switch self {
        case .atTime:    return 0
        case .minutes15: return 15 * 60
        case .hour1:     return 60 * 60
        case .day1:      return 24 * 60 * 60
        }
    }

    var localizedName: String {
        switch self {
        case .atTime:    return "calendar.reminder.atTime".l10n()
        case .minutes15: return "calendar.reminder.min15".l10n()
        case .hour1:     return "calendar.reminder.hour1".l10n()
        case .day1:      return "calendar.reminder.day1".l10n()
        }
    }
}

struct ReminderRule: Codable, Equatable {
    var isEnabled: Bool = false
    var lead: ReminderLead = .atTime
}

// MARK: - Calendar Entry

struct CalendarEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var type: CalendarEntryType
    var title: String
    var date: Date
    /// When true the entry has no meaningful time-of-day (shown as "All day").
    /// Optional so entries persisted before this field decode cleanly (nil = false).
    var isAllDay: Bool?
    var notes: String?
    var linkedDocumentID: UUID?
    var reminder: ReminderRule?
    var recurrence: RecurrenceRule
    var doctor: String?
    var specialization: MedicalSpecialization?
    /// Occurrence dates the user has marked complete (per-occurrence for recurring entries).
    var completedDates: [Date]
    /// Which Space this entry belongs to. `nil` means it predates Spaces and
    /// is treated as belonging to the default space.
    var spaceID: UUID?

    init(
        id: UUID = UUID(),
        type: CalendarEntryType,
        title: String,
        date: Date,
        isAllDay: Bool? = nil,
        notes: String? = nil,
        linkedDocumentID: UUID? = nil,
        reminder: ReminderRule? = nil,
        recurrence: RecurrenceRule = RecurrenceRule(),
        doctor: String? = nil,
        specialization: MedicalSpecialization? = nil,
        completedDates: [Date] = [],
        spaceID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.notes = notes
        self.linkedDocumentID = linkedDocumentID
        self.reminder = reminder
        self.recurrence = recurrence
        self.doctor = doctor
        self.specialization = specialization
        self.completedDates = completedDates
        self.spaceID = spaceID
    }

    /// Occurrence dates of this entry within a date range.
    func occurrences(in range: ClosedRange<Date>) -> [Date] {
        recurrence.occurrences(in: range, from: date)
    }

    /// Whether the occurrence on the given date is marked complete.
    func isCompleted(on date: Date) -> Bool {
        completedDates.contains(date)
    }

    /// A "Specialization · Doctor" subtitle, falling back to the entry type.
    var subtitle: String {
        let parts = [specialization?.localizedName, doctor]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? type.localizedName : parts.joined(separator: " · ")
    }

    /// Friendly notification headline, e.g. "Hey, Appointment with Dr Ahmed (Dentistry)".
    /// Appointments name the doctor (and specialization when set); other types use the title.
    var notificationHeadline: String {
        guard type == .appointment else { return title }
        let doc = doctor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !doc.isEmpty else {
            return String(format: L10n.Calendar.reminderApptPlain, title)
        }
        if let specialization {
            return String(format: L10n.Calendar.reminderApptWithSpec, doc, specialization.localizedName)
        }
        return String(format: L10n.Calendar.reminderAppt, doc)
    }
}
