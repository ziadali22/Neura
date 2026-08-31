import SwiftUI

struct GrowthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GrowthViewModel()
    @State private var showEditor = false
    @State private var editingEntry: GrowthEntry?

    var body: some View {
        VStack(spacing: 0) {
            navBar
            content
        }
        .background(Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { AnalyticsManager.shared.track(.growthViewed) }
        .sheet(isPresented: $showEditor) {
            AddGrowthEntrySheet(
                existing: nil,
                defaultHeightCm: viewModel.latest?.heightCm ?? 90,
                defaultWeightKg: viewModel.latest?.weightKg ?? 12,
                existingPhoto: nil,
                onSave: { entry, photo, removePhoto in
                    viewModel.save(entry: entry, photo: photo, removePhoto: removePhoto)
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            AddGrowthEntrySheet(
                existing: entry,
                defaultHeightCm: entry.heightCm,
                defaultWeightKg: entry.weightKg,
                existingPhoto: viewModel.photo(for: entry),
                onSave: { updated, photo, removePhoto in
                    viewModel.save(entry: updated, photo: photo, removePhoto: removePhoto)
                },
                onDelete: { viewModel.delete(entry) }
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

            Text(L10n.Growth.title)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.entries.isEmpty {
            emptyState
        } else {
            timeline
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "ruler")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
            Text(L10n.Growth.emptyTitle)
                .font(.headingS)
                .foregroundStyle(Color.textPrimary)
            Text(L10n.Growth.emptySubtitle)
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

                    if viewModel.chronologicalEntries.count >= 2 {
                        GrowthChartCard(entries: viewModel.chronologicalEntries)
                    }

                    ForEach(viewModel.entries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            GrowthEntryCard(
                                entry: entry,
                                photo: viewModel.photo(for: entry),
                                previous: viewModel.previous(before: entry)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.childName.isEmpty {
                Text(viewModel.childName)
                    .font(.headingS)
                    .foregroundStyle(Color.textPrimary)
            }
            if let latest = viewModel.latest {
                HStack(spacing: 16) {
                    Text(latest.heightLabel)
                        .font(.headingS)
                        .foregroundStyle(Color.accent)
                    Text(latest.weightLabel)
                        .font(.headingS)
                        .foregroundStyle(Color.accent)
                }
                Text(L10n.Growth.latest)
                    .font(.captionS)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private var addButton: some View {
        Button {
            showEditor = true
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
        .accessibilityLabel(L10n.Growth.add)
    }
}

#Preview {
    NavigationStack {
        GrowthView()
    }
}
