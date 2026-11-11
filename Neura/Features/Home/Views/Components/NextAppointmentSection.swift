import SwiftUI

/// Home's next-appointment block: a relative day heading and one appointment card.
struct NextAppointmentSection: View {
    let appointment: HomeNextAppointment
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(HomeNextAppointment.sectionTitle(for: appointment.occurrence))
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)

            NextAppointmentCard(
                date: appointment.occurrence,
                entry: appointment.entry,
                isCompleted: appointment.entry.isCompleted(on: appointment.occurrence),
                onTap: onTap,
                onToggle: onToggle
            )
            .padding(.horizontal, 20)
        }
    }
}

/// Date badge, title, doctor line, and a completion ring — matching the home appointment card.
private struct NextAppointmentCard: View {
    let date: Date
    let entry: CalendarEntry
    let isCompleted: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    VStack(spacing: 0) {
                        Text(date, format: .dateTime.day())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(entry.type.color)
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(.captionS)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(width: 40)

                    Rectangle()
                        .fill(Color.stroke)
                        .frame(width: 1, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headingXS)
                            .foregroundStyle(isCompleted ? Color.textTertiary : Color.textPrimary)
                            .strikethrough(isCompleted)
                            .lineLimit(1)
                        Text(entry.subtitle)
                            .font(.bodyS)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if entry.hasAttachment {
                        EntryAttachmentIcon()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilitySummary)

            Button(action: onToggle) {
                AppointmentCompletionRing(isCompleted: isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? L10n.Common.done : entry.title)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var accessibilitySummary: String {
        let day = date.formatted(date: .abbreviated, time: .omitted)
        return "\(entry.title), \(entry.subtitle), \(day)"
    }
}

/// Pale ring from the home appointment card. Fills with a check once the visit is marked done.
private struct AppointmentCompletionRing: View {
    let isCompleted: Bool

    var body: some View {
        if isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.accent)
        } else {
            Circle()
                .strokeBorder(Color.textTertiary, lineWidth: 1.5)
                .frame(width: 22, height: 22)
        }
    }
}

#Preview {
    let entry = CalendarEntry(
        type: .appointment,
        title: "MRI",
        date: Date(),
        doctor: "Dr. Jamie Brown",
        specialization: .neurology
    )
    let appointment = HomeNextAppointment(
        occurrence: entry.date,
        entry: entry,
        hideAt: entry.date.addingTimeInterval(60 * 60)
    )
    NextAppointmentSection(appointment: appointment, onTap: {}, onToggle: {})
        .padding(.vertical, 20)
        .background(Color.backgroundPrimary)
}
