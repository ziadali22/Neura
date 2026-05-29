import SwiftUI

struct HealthProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showGeneralData = false
    @State private var selectedSectionID: UUID?
    @State private var showAddSection = false
    @State private var newSectionTitle = ""

    // MARK: - General Data Progress

    private var generalDataFields: [String] {
        let g = viewModel.profile.generalData
        return [g.fullName, g.dateOfBirth, g.gender, g.height, g.weight, g.bloodType, g.insuranceStatus, g.myPhoneNumber, g.emergencyContactName, g.emergencyContactNumber]
    }

    private var filledCount: Int { generalDataFields.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count }
    private var totalCount: Int  { generalDataFields.count }
    private var isComplete: Bool { filledCount == totalCount }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 11) {
                    generalDataRow

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

    // MARK: - General Data Row

    var generalDataRow: some View {
        Button { showGeneralData = true } label: {
            HStack(spacing: 12) {
                Image("generalDataicon")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: isComplete ? 0 : 6) {
                    Text("General Data")
                        .font(.statLabel)
                        .foregroundStyle(Color.textPrimary)

                    if !isComplete {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(filledCount)/\(totalCount) filled")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.accent.opacity(0.15))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.accent)
                                        .frame(width: geo.size.width * CGFloat(filledCount) / CGFloat(totalCount), height: 4)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filledCount)
                                }
                            }
                            .frame(height: 4)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isComplete)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Nav Bar

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
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    NavigationStack {
        HealthProfileView()
    }
}
