import SwiftUI

/// First-use empty state for the calendar history/timeline.
struct AgendaEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("calendarImage")
                .resizable()
                .scaledToFit()
                .frame(height: 132)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(L10n.Calendar.agendaEmptyTitle)
                    .font(.headingS)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.Calendar.agendaEmptyMessage)
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 24)

            Button(action: onAdd) {
                Text(L10n.Calendar.agendaEmptyCTA)
                    .font(.headingXS)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AgendaEmptyState(onAdd: {})
        .background(Color.backgroundPrimary)
}
