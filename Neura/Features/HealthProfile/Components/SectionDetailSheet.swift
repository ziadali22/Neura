import SwiftUI

struct SectionDetailSheet: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    let sectionID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showAddEntry = false
    @State private var newEntryText = ""
    @State private var editingEntry: HealthProfile.HealthSection.Entry?

    private var section: HealthProfile.HealthSection? {
        viewModel.profile.sections.first { $0.id == sectionID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.textPrimary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if let section {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.displayXL)
                            .foregroundColor(.textPrimary)
                            .padding(.bottom, 8)

                        if section.entries.isEmpty {
                            emptyState
                        }

                        ForEach(section.entries) { entry in
                            entryRow(entry)
                        }

                        addEntryButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.backgroundPrimary)
        .alert("Add Entry", isPresented: $showAddEntry) {
            TextField("e.g. Vitamin D", text: $newEntryText)
            Button("Add") {
                guard !newEntryText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                viewModel.addEntry(to: sectionID, text: newEntryText.trimmingCharacters(in: .whitespaces))
                newEntryText = ""
            }
            Button("Cancel", role: .cancel) { newEntryText = "" }
        }
        .sheet(item: $editingEntry) { entry in
            EditFieldSheet(
                fieldName: section?.title ?? "",
                value: entry.text
            ) { newValue in
                viewModel.updateEntry(in: sectionID, entryID: entry.id, text: newValue)
            }
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Subviews

private extension SectionDetailSheet {
    var emptyState: some View {
        Text("No entries yet. Tap below to add one.")
            .font(.bodyL)
            .foregroundColor(.textTertiary)
            .padding(.vertical, 8)
    }

    func entryRow(_ entry: HealthProfile.HealthSection.Entry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HStack {
                Text(entry.text)
                    .font(.bodyL)
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    viewModel.removeEntry(from: sectionID, entryID: entry.id)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    var addEntryButton: some View {
        Button {
            newEntryText = ""
            showAddEntry = true
        } label: {
            HStack {
                Text("Add Entry")
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
    SectionDetailSheet(
        viewModel: HealthProfileViewModel(),
        sectionID: UUID()
    )
}
