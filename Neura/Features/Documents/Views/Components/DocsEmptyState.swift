import SwiftUI

struct DocsEmptyState: View {
    let onAddDocument: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            Image("scanDocs")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(.bottom, 40)

            // Text
            VStack(spacing: 10) {
                Text("No documents yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Add or scan your first medical record.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 36)

            // CTA button
            Button(action: onAddDocument) {
                Text("Add document")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 190)
                    .padding(.vertical, 18)
                    .background(Color.textPrimary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DocsEmptyState(onAddDocument: {})
        .background(Color.backgroundPrimary)
}
