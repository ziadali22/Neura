import SwiftUI

/// Bottom sheet prompting the user to update when a newer version is live on
/// the App Store. Presented from HomeView once per launch.
struct AppUpdateSheet: View {
    let update: AppUpdateInfo

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 24)

                iconView
                    .padding(.top, 16)

                infoSection
                    .padding(.top, 24)

                Spacer()

                VStack(spacing: 12) {
                    updateButton
                    laterButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            closeButton
                .padding(.top, 14)
                .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundModal)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textPrimary)
                .frame(width: 28, height: 28)
                .background(Color.surfaceWhite)
                .clipShape(Circle())
        }
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.accent.opacity(0.12))
                .frame(width: 96, height: 96)

            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accent)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 12) {
            Text(L10n.Home.AppUpdate.title)
                .font(.headingL)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.Home.AppUpdate.subtitle(update.version))
                .font(.bodyL)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Buttons

    private var updateButton: some View {
        Button {
            openURL(update.appStoreURL)
            dismiss()
        } label: {
            Text(L10n.Home.AppUpdate.updateNow)
                .font(.headingS)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.surfaceDark)
                .clipShape(Capsule())
        }
    }

    private var laterButton: some View {
        Button { dismiss() } label: {
            Text(L10n.Common.maybeLater)
                .font(.buttonL)
                .foregroundColor(.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AppUpdateSheet(
                update: AppUpdateInfo(
                    version: "1.2.0",
                    appStoreURL: URL(string: "https://apps.apple.com")!
                )
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(32)
        }
}
