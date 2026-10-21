import SwiftUI

struct GrowthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GrowthViewModel()
    @State private var showEditor = false
    @State private var editingEntry: GrowthEntry?
    @State private var previewingEntry: GrowthEntry?

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
        .fullScreenCover(item: $previewingEntry) { entry in
            GrowthPhotoGalleryView(entries: viewModel.photoEntries, initialID: entry.id)
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
            GrowthEmptyState { showEditor = true }
        } else {
            timeline
        }
    }

    private var timeline: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    GrowthChartCard(
                        points: viewModel.trendPoints,
                        totals: viewModel.trendTotals,
                        periodLabel: viewModel.trendPeriodLabel
                    )

                    ForEach(viewModel.entries) { entry in
                        GrowthEntryCard(
                            entry: entry,
                            photo: viewModel.photo(for: entry),
                            previous: viewModel.previous(before: entry),
                            onPreviewPhoto: { previewingEntry = entry },
                            onEdit: { editingEntry = entry }
                        )
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
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.childName.isEmpty {
                Text(viewModel.childName)
                    .font(.headingL)
                    .foregroundStyle(Color.textPrimary)
            }
            if let latest = viewModel.latest {
                let previous = viewModel.previous(before: latest)
                HStack(alignment: .top, spacing: 24) {
                    GrowthStatColumn(
                        label: L10n.Growth.height,
                        value: latest.heightLabel,
                        delta: latest.heightDelta(from: previous),
                        valueFont: .statValue,
                        labelPlacement: .below
                    )
                    GrowthStatColumn(
                        label: L10n.Growth.weight,
                        value: latest.weightLabel,
                        delta: latest.weightDelta(from: previous),
                        valueFont: .statValue,
                        labelPlacement: .below
                    )
                    Spacer(minLength: 0)
                }
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
