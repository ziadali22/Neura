import SwiftUI

struct VaccinationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showAddEntry = false
    @State private var editingEntry: HealthProfile.HealthSection.Entry?

    private var section: HealthProfile.HealthSection? {
        viewModel.profile.sections.first { $0.title == HealthProfile.vaccinationsSectionTitle }
    }

    private var config: SectionFieldConfig {
        SectionFieldConfig.forSection(HealthProfile.vaccinationsSectionTitle)
    }

    private var sortedEntries: [HealthProfile.HealthSection.Entry] {
        guard let section else { return [] }
        return section.entries.sorted { dateValue(from: $0.field1) > dateValue(from: $1.field1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            content
        }
        .background(Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.ensureVaccinationsSection() }
        .sheet(isPresented: $showAddEntry) {
            AddEntrySheet(config: config) { name, f1, f2, notes in
                guard let id = section?.id else { return }
                viewModel.addEntry(to: id, text: name, field1: f1, field2: f2, notes: notes)
            }
        }
        .sheet(item: $editingEntry) { entry in
            AddEntrySheet(
                config: config,
                entry: entry,
                onSave: { name, f1, f2, notes in
                    guard let id = section?.id else { return }
                    viewModel.updateEntry(in: id, entryID: entry.id, text: name, field1: f1, field2: f2, notes: notes)
                },
                onDelete: {
                    guard let id = section?.id else { return }
                    withAnimation {
                        viewModel.removeEntry(from: id, entryID: entry.id)
                    }
                }
            )
        }
    }

    private var navBar: some View {
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
            .accessibilityLabel(L10n.Common.back)

            Text(L10n.HealthProfile.Section.vaccinations)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if sortedEntries.isEmpty {
            emptyState
        } else {
            timeline
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image("Vaccination")
                .resizable()
                .scaledToFit()
                .frame(height: 140)
                .accessibilityHidden(true)
            Text(L10n.HealthProfile.vaccinationsEmptyTitle)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
            Text(L10n.HealthProfile.vaccinationsEmptySubtitle)
                .font(.bodyS)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            addButton
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private var timeline: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(sortedEntries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            VaccinationEntryCard(
                                name: entry.text,
                                dateGiven: entry.field1,
                                dose: entry.field2,
                                notes: entry.notes
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }

            addButton
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let latest = sortedEntries.first {
            VStack(alignment: .leading, spacing: 8) {
                Text(latest.text)
                    .font(.headingS)
                    .foregroundStyle(Color.textPrimary)
                if !latest.field1.isEmpty {
                    Text(latest.field1)
                        .font(.headingS)
                        .foregroundStyle(Color.accent)
                }
                Text(L10n.HealthProfile.vaccinationsLatest)
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private var addButton: some View {
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
        .accessibilityLabel(config.addTitle)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    private func dateValue(from value: String) -> Date {
        Self.dateFormatter.date(from: value) ?? .distantPast
    }
}

#Preview {
    NavigationStack {
        VaccinationsView()
    }
}
