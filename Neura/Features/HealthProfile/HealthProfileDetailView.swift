import SwiftUI

struct HealthProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showAddSection = false
    @State private var addingEntryToSection: UUID?
    @State private var newEntryText = ""
    @State private var newSectionTitle = ""
    @State private var editingGeneralField: GeneralField?
    @State private var editFieldValue = ""

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    generalDataCard

                    ForEach(viewModel.profile.sections) { section in
                        sectionCard(section)
                    }

                    addFieldCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(Color.backgroundPrimary)
        .overlay(alignment: .bottom) {
            shareButton
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert("Add Entry", isPresented: Binding(
            get: { addingEntryToSection != nil },
            set: { if !$0 { addingEntryToSection = nil } }
        )) {
            TextField("e.g. Vitamin D", text: $newEntryText)
            Button("Add") {
                guard !newEntryText.trimmingCharacters(in: .whitespaces).isEmpty,
                      let sectionID = addingEntryToSection else { return }
                viewModel.addEntry(to: sectionID, text: newEntryText.trimmingCharacters(in: .whitespaces))
                newEntryText = ""
                addingEntryToSection = nil
            }
            Button("Cancel", role: .cancel) {
                newEntryText = ""
                addingEntryToSection = nil
            }
        }
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
    }
}

// MARK: - General Field Mapping

private struct GeneralField: Identifiable {
    let id = UUID()
    let label: String
    let keyPath: WritableKeyPath<HealthProfile.GeneralData, String>
    let value: String
}

// MARK: - Subviews

private extension HealthProfileDetailView {

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
            .init(label: "Full Name", keyPath: \.fullName, value: data.fullName),
            .init(label: "Date of Birth", keyPath: \.dateOfBirth, value: data.dateOfBirth),
            .init(label: "Gender", keyPath: \.gender, value: data.gender),
            .init(label: "Height", keyPath: \.height, value: data.height),
            .init(label: "Weight", keyPath: \.weight, value: data.weight),
            .init(label: "Blood Type", keyPath: \.bloodType, value: data.bloodType),
            .init(label: "Insurance Status", keyPath: \.insuranceStatus, value: data.insuranceStatus),
        ]

        return VStack(alignment: .leading, spacing: 16) {
            Text("General Data")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    VStack(spacing: 0) {
                        HStack {
                            Text(field.label)
                                .font(.bodyL)
                                .foregroundColor(.textTertiary)

                            Spacer()

                            if field.value.isEmpty {
                                Button {
                                    editFieldValue = ""
                                    editingGeneralField = field
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Add")
                                            .font(.bodyL)
                                            .foregroundColor(.textTertiary)
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.textTertiary)
                                    }
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
                        .padding(.vertical, 2)

                        if index < fields.count - 1 {
                            Divider()
                                .padding(.top, 12)
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Dynamic Sections

    func sectionCard(_ section: HealthProfile.HealthSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.textPrimary)

            if section.entries.isEmpty {
                Text("Not set")
                    .font(.bodyL)
                    .foregroundColor(.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.entries) { entry in
                        Text(entry.text)
                            .font(.bodyL)
                            .foregroundColor(.textPrimary)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.removeEntry(from: section.id, entryID: entry.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            Button {
                newEntryText = ""
                addingEntryToSection = section.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add")
                        .font(.bodyS)
                }
                .foregroundColor(.accent)
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    viewModel.removeSection(id: section.id)
                }
            } label: {
                Label("Delete Section", systemImage: "trash")
            }
        }
    }

    // MARK: Add Field

    var addFieldCard: some View {
        Button {
            newSectionTitle = ""
            showAddSection = true
        } label: {
            HStack {
                Text("Add Field")
                    .font(.system(size: 18, weight: .medium))
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
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Share

    var shareButton: some View {
        Button {
            // TODO: Share action
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
        }
    }
}

#Preview {
    NavigationStack {
        HealthProfileDetailView()
    }
}
