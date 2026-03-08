import SwiftUI

struct HealthProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showGeneralData = false
    @State private var selectedSectionID: UUID?
    @State private var showAddSection = false
    @State private var newSectionTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 11) {
                    SettingsRow(icon: "generalDataicon", title: "General Data") {
                        showGeneralData = true
                    }

                    ForEach(viewModel.profile.sections) { section in
                        SettingsRow(
                            icon: iconForSection(section.title),
                            title: section.title
                        ) {
                            selectedSectionID = section.id
                        }
                    }

                    addFieldButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showGeneralData) {
            GeneralDataSheet(viewModel: viewModel)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(
            get: { selectedSectionID != nil },
            set: { if !$0 { selectedSectionID = nil } }
        )) {
            if let id = selectedSectionID {
                SectionDetailSheet(viewModel: viewModel, sectionID: id)
                    .presentationDragIndicator(.hidden)
            }
        }
        .alert("Add Section", isPresented: $showAddSection) {
            TextField("Section title", text: $newSectionTitle)
            Button("Add") {
                guard !newSectionTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                viewModel.addSection(title: newSectionTitle.trimmingCharacters(in: .whitespaces))
                newSectionTitle = ""
            }
            Button("Cancel", role: .cancel) { newSectionTitle = "" }
        }
    }

    private func iconForSection(_ title: String) -> String {
        switch title.lowercased() {
        case let t where t.contains("condition"): return "knownCondition"
        case let t where t.contains("symptom"): return "Heartbeat"
        case let t where t.contains("allerg"): return "Leaf"
        case let t where t.contains("medication") || t.contains("supplement"): return "Pill"
        case let t where t.contains("family"): return "family"
        case let t where t.contains("mobility"): return "mobility"
        default: return "generalDataicon"
        }
    }
}

// MARK: - Subviews

private extension HealthProfileView {
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

            Text("Health Profile")
                .font(.headingS)
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var addFieldButton: some View {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    NavigationStack {
        HealthProfileView()
    }
}
