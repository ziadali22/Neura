import SwiftUI

struct HealthReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileVM = HealthProfileViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var isGenerating = false
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.textTertiary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.accent.opacity(0.1))
                                .frame(width: 64, height: 64)

                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accent)
                        }

                        Text(L10n.HealthProfile.Report.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text(L10n.HealthProfile.Report.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.top, 20)

                    // What's included
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.HealthProfile.Report.whatsIncluded)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)

                        featureRow(icon: "person.text.rectangle", title: L10n.HealthProfile.Report.feature1Title, subtitle: L10n.HealthProfile.Report.feature1Subtitle)
                        featureRow(icon: "doc.on.doc", title: L10n.HealthProfile.Report.feature2Title, subtitle: L10n.HealthProfile.Report.feature2Subtitle)
                        featureRow(icon: "calendar.badge.clock", title: L10n.HealthProfile.Report.feature3Title, subtitle: L10n.HealthProfile.Report.feature3Subtitle)
                        featureRow(icon: "paintbrush", title: L10n.HealthProfile.Report.feature4Title, subtitle: L10n.HealthProfile.Report.feature4Subtitle)
                    }

                    // Generate button
                    Button {
                        generateReport()
                    } label: {
                        HStack(spacing: 10) {
                            if isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 16))
                            }

                            Text(isGenerating ? L10n.HealthProfile.Report.generating : L10n.HealthProfile.Report.generate)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.accent)
                        .clipShape(Capsule())
                        .shadow(color: Color.accent.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isGenerating)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color.backgroundPrimary)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accent.opacity(0.08))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.accent.opacity(0.6))
        }
        .padding(12)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    private func generateReport() {
        isGenerating = true
        UserDefaults.standard.set(true, forKey: "neura_has_generated_health_report")

        Task.detached(priority: .userInitiated) {
            let profile = await MainActor.run { profileVM.profile }
            let documents = DocumentFileManager.shared.loadMetadata()
                .filter { $0.fileExists }
                .sorted { $0.createdAt > $1.createdAt }

            let generator = HealthReportGenerator()
            let url = generator.generate(profile: profile, documents: documents)

            await MainActor.run {
                isGenerating = false

                guard let url else { return }

                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let root = windowScene.keyWindow?.rootViewController {
                    var topVC = root
                    while let presented = topVC.presentedViewController { topVC = presented }
                    activityVC.popoverPresentationController?.sourceView = topVC.view
                    topVC.present(activityVC, animated: true)
                }
            }
        }
    }
}

#Preview {
    HealthReportSheet()
}
