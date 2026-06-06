import SwiftUI

struct HealthProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showHealthReport = false
    @State private var isGeneratingReport = false
    @State private var isSharingProfile = false
    @State private var navigateToEdit = false

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    generalDataCard

                    ForEach(viewModel.profile.sections) { section in
                        sectionCard(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(Color.backgroundPrimary)
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                reportButton
                shareButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToEdit) {
            HealthProfileView()
        }
        .onChange(of: navigateToEdit) { _, isEditing in
            // The edit screen uses a separate view model that persists changes to
            // disk. Reload from disk on return so edits reflect immediately instead
            // of only after the detail view is recreated.
            if !isEditing { viewModel.reload() }
        }
        .sheet(isPresented: $showHealthReport) {
            HealthReportSheet()
                .presentationDetents([.height(650)])
                .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Subviews

private extension HealthProfileDetailView {

    // MARK: Nav Bar

    var navBar: some View {
        ZStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text("Health Profile")
                    .font(.headingS)
                    .foregroundColor(.textPrimary)

                Text(updatedLabel)
                    .font(.captionS)
                    .foregroundColor(.textTertiary)
            }

            Button { navigateToEdit = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var updatedLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Updated \(formatter.localizedString(for: viewModel.profile.lastUpdated, relativeTo: Date()))"
    }

    // MARK: General Data

    var generalDataCard: some View {
        let data = viewModel.profile.generalData
        let fields: [(label: String, value: String)] = [
            ("Full Name",           data.fullName),
            ("Date of Birth",       data.dateOfBirth),
            ("Gender",              data.gender),
            ("Height",              data.height),
            ("Weight",              data.weight),
            ("Blood Type",          data.bloodType),
            ("Insurance Status",    data.insuranceStatus),
            ("My Number",           data.myPhoneNumber),
            ("Emergency Contact",   data.emergencyContactName),
            ("Emergency Number",    data.emergencyContactNumber),
        ] + data.customFields.map { (label: $0.label, value: $0.value) }

        return VStack(alignment: .leading, spacing: 0) {
            Text("General Data")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, 16)

            ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                VStack(spacing: 0) {
                    HStack {
                        Text(field.label)
                            .font(.bodyL)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        Text(field.value.isEmpty ? "—" : field.value)
                            .font(.bodyL)
                            .foregroundColor(field.value.isEmpty ? .textTertiary : .textPrimary)
                    }
                    .padding(.vertical, 14)

                    if index < fields.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: Section Cards

    func sectionCard(_ section: HealthProfile.HealthSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)

            if section.entries.isEmpty {
                Text("No entries yet")
                    .font(.bodyS)
                    .foregroundColor(.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(section.entries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(entry.text)
                                .font(.bodyL)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: Report Button

    var reportButton: some View {
        Button {
            let hasGeneratedBefore = UserDefaults.standard.bool(forKey: "neura_has_generated_health_report")
            if hasGeneratedBefore {
                generateAndShareReport()
            } else {
                showHealthReport = true
            }
        } label: {
            ZStack {
                if isGeneratingReport {
                    ProgressView().tint(Color.accent)
                } else {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accent)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.surfaceWhite)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .disabled(isGeneratingReport)
    }

    // MARK: Share Button

    var shareButton: some View {
        Button {
            generateAndShareProfile()
        } label: {
            ZStack {
                if isSharingProfile {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Text("Share")
                            .font(.headingS)
                            .foregroundColor(.white)
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accent)
            .clipShape(Capsule())
            .shadow(color: Color.accent.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .disabled(isSharingProfile)
    }

    // MARK: - Helpers

    func generateAndShareProfile() {
        guard !isSharingProfile else { return }
        isSharingProfile = true

        Task.detached(priority: .userInitiated) {
            let profile = await MainActor.run { viewModel.profile }
            let url = HealthProfileViewModel.generatePDF(for: profile)

            await MainActor.run {
                isSharingProfile = false
                if let url { shareURL(url) }
            }
        }
    }

    func generateAndShareReport() {
        guard !isGeneratingReport else { return }
        isGeneratingReport = true

        Task.detached(priority: .userInitiated) {
            let profile = await MainActor.run { viewModel.profile }
            let documents = DocumentFileManager.shared.loadMetadata()
                .filter { $0.fileExists }
                .sorted { $0.createdAt > $1.createdAt }

            let url = HealthReportGenerator().generate(profile: profile, documents: documents)

            await MainActor.run {
                isGeneratingReport = false
                if let url { shareURL(url) }
            }
        }
    }

    func shareURL(_ url: URL) {
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

#Preview {
    NavigationStack {
        HealthProfileDetailView()
    }
}
