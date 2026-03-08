import Foundation
import Combine

@MainActor
final class HealthProfileViewModel: ObservableObject {
    @Published var profile: HealthProfile

    private static let storageKey = "health_profile_data"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(HealthProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = .sample
        }
    }

    // MARK: - General Data

    func updateGeneralField(_ keyPath: WritableKeyPath<HealthProfile.GeneralData, String>, value: String) {
        profile.generalData[keyPath: keyPath] = value
        save()
    }

    // MARK: - Sections

    func addEntry(to sectionID: UUID, text: String) {
        guard let index = profile.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        profile.sections[index].entries.append(.init(text: text))
        save()
    }

    func updateEntry(in sectionID: UUID, entryID: UUID, text: String) {
        guard let sIndex = profile.sections.firstIndex(where: { $0.id == sectionID }),
              let eIndex = profile.sections[sIndex].entries.firstIndex(where: { $0.id == entryID }) else { return }
        profile.sections[sIndex].entries[eIndex].text = text
        save()
    }

    func removeEntry(from sectionID: UUID, entryID: UUID) {
        guard let sIndex = profile.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        profile.sections[sIndex].entries.removeAll { $0.id == entryID }
        save()
    }

    func addSection(title: String) {
        profile.sections.append(.init(title: title))
        save()
    }

    func removeSection(id: UUID) {
        profile.sections.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private func save() {
        profile.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
