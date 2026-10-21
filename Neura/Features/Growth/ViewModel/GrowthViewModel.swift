import Combine
import SwiftUI

@MainActor
final class GrowthViewModel: ObservableObject {
    let profileViewModel: HealthProfileViewModel
    private var cancellable: AnyCancellable?

    init() {
        let profileViewModel = HealthProfileViewModel()
        self.profileViewModel = profileViewModel
        cancellable = profileViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var entries: [GrowthEntry] {
        profileViewModel.profile.growthEntries.sorted { $0.date > $1.date }
    }

    var chronologicalEntries: [GrowthEntry] {
        profileViewModel.profile.growthEntries.sorted { $0.date < $1.date }
    }

    var latest: GrowthEntry? { entries.first }

    var childName: String {
        let name = profileViewModel.profile.generalData.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return ActiveSpaceManager.shared.currentSpace?.name ?? ""
    }

    // MARK: - Trend

    var trendPoints: [GrowthTrendPoint] {
        GrowthTrendPoint.points(from: profileViewModel.profile.growthEntries)
    }

    /// Growth from the first reading to the latest, used under the unified chart.
    var trendTotals: GrowthYearTotals {
        let points = trendPoints
        guard let first = points.first, let last = points.last else { return .zero }
        return GrowthYearTotals(
            heightCm: last.heightCm - first.heightCm,
            weightKg: last.weightKg - first.weightKg
        )
    }

    var trendPeriodLabel: String {
        let years = Set(trendPoints.map { Calendar.current.component(.year, from: $0.date) }).sorted()
        guard let first = years.first, let last = years.last else { return "" }
        if first == last { return String(first) }
        return "\(first)–\(last)"
    }

    // MARK: - Photos

    /// Entries that actually have a photo, oldest first, so swiping the gallery forward
    /// reads as the child growing.
    var photoEntries: [GrowthEntry] {
        chronologicalEntries.filter { $0.photoFilename != nil }
    }

    // MARK: - Entries

    func previous(before entry: GrowthEntry) -> GrowthEntry? {
        profileViewModel.profile.growthEntries
            .filter { $0.date < entry.date }
            .max(by: { $0.date < $1.date })
    }

    func photo(for entry: GrowthEntry) -> UIImage? {
        guard let filename = entry.photoFilename else { return nil }
        return GrowthPhotoStore.shared.loadImage(filename: filename)
    }

    func save(entry: GrowthEntry, photo: UIImage?, removePhoto: Bool) {
        var saved = entry
        if removePhoto {
            if saved.photoFilename != nil {
                GrowthPhotoStore.shared.delete(for: saved.id)
                SyncQueueManager.shared.enqueueGrowthPhotoDelete(saved.id)
            }
            saved.photoFilename = nil
        } else if let photo {
            saved.photoFilename = GrowthPhotoStore.shared.save(photo, for: saved.id)
            if saved.photoFilename != nil {
                SyncQueueManager.shared.enqueueGrowthPhotoUpload(saved.id)
            }
        }
        let isEdit = profileViewModel.profile.growthEntries.contains(where: { $0.id == entry.id })
        profileViewModel.upsertGrowthEntry(saved)
        AnalyticsManager.shared.track(.growthEntrySaved, properties: [
            "has_photo": saved.photoFilename != nil,
            "is_edit": isEdit
        ])
    }

    func delete(_ entry: GrowthEntry) {
        profileViewModel.removeGrowthEntry(id: entry.id)
    }
}
