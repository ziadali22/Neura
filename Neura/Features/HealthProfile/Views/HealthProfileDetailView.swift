import SwiftUI
import UIKit

struct HealthProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showAddSection = false
    @State private var newSectionTitle = ""
    @State private var editingGeneralField: GeneralField?
    @State private var editFieldValue = ""
    @State private var selectedSection: SectionSheetID?
    @State private var showHealthReport = false

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    generalDataCard

                    ForEach(viewModel.profile.sections) { section in
                        sectionCard(section)
                    }

                    addHealthInfoCard
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
        .alert("Add Section", isPresented: $showAddSection) {
            TextField("Section title", text: $newSectionTitle)
            Button("Add") {
                guard !newSectionTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                viewModel.addSection(title: newSectionTitle.trimmingCharacters(in: .whitespaces))
                newSectionTitle = ""
            }
            Button("Cancel", role: .cancel) {
                newSectionTitle = ""
            }
        }
        .alert("Edit", isPresented: Binding(
            get: { editingGeneralField != nil },
            set: { if !$0 { editingGeneralField = nil } }
        )) {
            TextField("Value", text: $editFieldValue)
            Button("Save") {
                guard let field = editingGeneralField else { return }
                viewModel.updateGeneralField(field.keyPath, value: editFieldValue.trimmingCharacters(in: .whitespaces))
                editFieldValue = ""
                editingGeneralField = nil
            }
            Button("Cancel", role: .cancel) {
                editFieldValue = ""
                editingGeneralField = nil
            }
        }
        .sheet(item: $selectedSection) { item in
            SectionDetailSheet(viewModel: viewModel, sectionID: item.id)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showHealthReport) {
            HealthReportSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Sheet ID wrapper

private struct SectionSheetID: Identifiable {
    let id: UUID
}

// MARK: - General Field Mapping

private struct GeneralField: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let keyPath: WritableKeyPath<HealthProfile.GeneralData, String>
    let value: String
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
        let fields: [GeneralField] = [
            .init(label: "Full Name", placeholder: "Add Name", keyPath: \.fullName, value: data.fullName),
            .init(label: "Date of Birth", placeholder: "Add Date", keyPath: \.dateOfBirth, value: data.dateOfBirth),
            .init(label: "Gender", placeholder: "Add Gender", keyPath: \.gender, value: data.gender),
            .init(label: "Height", placeholder: "Add Height", keyPath: \.height, value: data.height),
            .init(label: "Weight", placeholder: "Add Weight", keyPath: \.weight, value: data.weight),
            .init(label: "Blood Type", placeholder: "Select Blood Type", keyPath: \.bloodType, value: data.bloodType),
            .init(label: "Insurance Status", placeholder: "Add Status", keyPath: \.insuranceStatus, value: data.insuranceStatus),
            .init(label: "Emergency Contact", placeholder: "Add Contact", keyPath: \.emergencyContact, value: data.emergencyContact),
        ]

        return VStack(alignment: .leading, spacing: 0) {
            Text("General Data")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, 16)

            ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                VStack(spacing: 0) {
                    HStack {
                        Text(field.label)
                            .font(.bodyL)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        if field.value.isEmpty {
                            Button {
                                editFieldValue = ""
                                editingGeneralField = field
                            } label: {
                                Text(field.placeholder)
                                    .font(.bodyL)
                                    .foregroundColor(.accent)
                            }
                        } else {
                            Text(field.value)
                                .font(.bodyL)
                                .foregroundColor(.textPrimary)
                                .onTapGesture {
                                    editFieldValue = field.value
                                    editingGeneralField = field
                                }
                        }
                    }
                    .padding(.vertical, 14)

                    if index < fields.count - 1 {
                        Divider()
                            .foregroundColor(.stroke)
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
        Button {
            selectedSection = SectionSheetID(id: section.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(section.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accent)
                }

                if section.entries.isEmpty {
                    Text(sectionHint(section.title))
                        .font(.bodyS)
                        .foregroundColor(.textTertiary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(section.entries) { entry in
                            Text(entry.text)
                                .font(.bodyL)
                                .foregroundColor(.textSecondary)
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
        .buttonStyle(ScaleButtonStyle())
    }

    func sectionHint(_ title: String) -> String {
        switch title.lowercased() {
        case let t where t.contains("condition"):
            return "Add conditions diagnosed by a doctor"
        case let t where t.contains("medication") || t.contains("supplement"):
            return "Add medications or supplements you take"
        case let t where t.contains("allerg"):
            return "Add allergies if you have any"
        case let t where t.contains("symptom"):
            return "Add if you have current symptoms"
        case let t where t.contains("family"):
            return "Add known conditions in family"
        default:
            return "Tap to add entries"
        }
    }

    // MARK: Add Health Information

    var addHealthInfoCard: some View {
        Button {
            newSectionTitle = ""
            showAddSection = true
        } label: {
            HStack {
                Text("Add Health Information")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Report

    var reportButton: some View {
        Button {
            showHealthReport = true
        } label: {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 20))
                .foregroundColor(.accent)
                .frame(width: 56, height: 56)
                .background(Color.surfaceWhite)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: Share

    var shareButton: some View {
        Button {
            if let url = viewModel.generatePDF() {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = windowScene.windows.first?.rootViewController {
                    var topVC = root
                    while let presented = topVC.presentedViewController { topVC = presented }
                    activityVC.popoverPresentationController?.sourceView = topVC.view
                    topVC.present(activityVC, animated: true)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text("Share")
                    .font(.headingS)
                    .foregroundColor(.white)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accent)
            .clipShape(Capsule())
            .shadow(color: Color.accent.opacity(0.3), radius: 10, x: 0, y: 4)
        }
    }
}

#Preview {
    NavigationStack {
        HealthProfileDetailView()
    }
}
