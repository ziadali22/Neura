import SwiftUI

struct VaccinationEntryCard: View {
    let name: String
    let dateGiven: String
    let dose: String
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headingXS)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.leading)

                    if !dateGiven.isEmpty {
                        Text(dateGiven)
                            .font(.captionS)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer(minLength: 0)
            }

            if !dose.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.HealthProfile.Entry.vaccinationDose)
                        .font(.captionS)
                        .foregroundStyle(Color.textTertiary)
                    Text(dose)
                        .font(.headingS)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            if !notes.isEmpty {
                Text(notes)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Circle()
            .fill(Color.accent.opacity(0.15))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: "syringe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accent)
            }
            .accessibilityHidden(true)
    }
}
