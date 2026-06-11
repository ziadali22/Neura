import SwiftUI

struct SectionDetailSheet: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    let sectionID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showAddEntry = false
    @State private var editingEntry: HealthProfile.HealthSection.Entry?

    private var section: HealthProfile.HealthSection? {
        viewModel.profile.sections.first { $0.id == sectionID }
    }

    private var config: SectionFieldConfig {
        SectionFieldConfig.forSection(section?.title ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            if let section, section.entries.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let section {
                            ForEach(section.entries) { entry in
                                entryCard(entry)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.backgroundPrimary)
        .overlay(alignment: .bottom) {
            addButton
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddEntry) {
            AddEntrySheet(config: config) { name, f1, f2, notes in
                viewModel.addEntry(to: sectionID, text: name, field1: f1, field2: f2, notes: notes)
            }
        }
        .sheet(item: $editingEntry) { entry in
            AddEntrySheet(
                config: config,
                entry: entry,
                onSave: { name, f1, f2, notes in
                    viewModel.updateEntry(in: sectionID, entryID: entry.id, text: name, field1: f1, field2: f2, notes: notes)
                },
                onDelete: {
                    withAnimation {
                        viewModel.removeEntry(from: sectionID, entryID: entry.id)
                    }
                }
            )
        }
    }
}

// MARK: - Subviews

private extension SectionDetailSheet {

    var navBar: some View {
        ZStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(section?.localizedTitle ?? "")
                .font(.headingS)
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(.textTertiary.opacity(0.5))

            Text(L10n.HealthProfile.noEntries)
                .font(.headingS)
                .foregroundColor(.textPrimary)

            Text(L10n.HealthProfile.noEntriesSubtitle)
                .font(.bodyS)
                .foregroundColor(.textTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func entryCard(_ entry: HealthProfile.HealthSection.Entry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.accent)

                if !entry.field1.isEmpty {
                    detailRow(config.field1Label, value: entry.field1)
                }

                if !entry.field2.isEmpty {
                    detailRow(config.field2Label, value: entry.field2)
                }

                detailRow(L10n.HealthProfile.notes, value: entry.notes.isEmpty ? "-" : entry.notes)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text(value)
                .font(.bodyS)
                .foregroundColor(.textSecondary)
        }
    }

    var addButton: some View {
        Button {
            showAddEntry = true
        } label: {
            HStack(spacing: 8) {
                Text(L10n.Common.add)
                    .font(.headingS)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accent)
            .clipShape(Capsule())
            .shadow(color: Color.accent.opacity(0.3), radius: 10, x: 0, y: 4)
        }
    }
}

#Preview {
    SectionDetailSheet(
        viewModel: HealthProfileViewModel(),
        sectionID: UUID()
    )
}
