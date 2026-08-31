import SwiftUI

struct SectionDetailSheet: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    let sectionID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showAddEntry = false
    @State private var editingEntry: HealthProfile.HealthSection.Entry?
    @State private var emptyStateAppear = false

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
                Image(systemName: LanguageManager.shared.backChevronSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(section?.localizedTitle ?? "")
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: emptyIcon)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
                .scaleEffect(emptyStateAppear ? 1 : 0.8)
                .opacity(emptyStateAppear ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: emptyStateAppear)

            Text(L10n.HealthProfile.noEntries)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
                .opacity(emptyStateAppear ? 1 : 0)
                .offset(y: emptyStateAppear ? 0 : 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: emptyStateAppear)

            Text(L10n.HealthProfile.noEntriesSubtitle)
                .font(.bodyS)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(emptyStateAppear ? 1 : 0)
                .offset(y: emptyStateAppear ? 0 : 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.16), value: emptyStateAppear)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !emptyStateAppear else { return }
            emptyStateAppear = true
        }
    }

    private var emptyIcon: String {
        let title = section?.title.lowercased() ?? ""
        if title.contains("vaccin") { return "syringe" }
        if title.contains("allerg") { return "leaf" }
        if title.contains("medication") || title.contains("supplement") { return "pills" }
        if title.contains("condition") { return "heart.text.clipboard" }
        if title.contains("symptom") { return "waveform.path.ecg" }
        if title.contains("family") { return "figure.2.and.child.holdinghands" }
        return "square.and.pencil"
    }

    func entryCard(_ entry: HealthProfile.HealthSection.Entry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HealthEntryCard(title: entry.text, details: details(for: entry))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func details(for entry: HealthProfile.HealthSection.Entry) -> [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if !entry.field1.isEmpty {
            rows.append((config.field1Label, entry.field1))
        }
        if !entry.field2.isEmpty {
            rows.append((config.field2Label, entry.field2))
        }
        if !entry.notes.isEmpty {
            rows.append((L10n.HealthProfile.notes, entry.notes))
        }
        return rows
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accent)
            .clipShape(Capsule())
            .shadow(color: Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    SectionDetailSheet(
        viewModel: HealthProfileViewModel(),
        sectionID: UUID()
    )
}
