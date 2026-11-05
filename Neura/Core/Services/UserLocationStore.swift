import Foundation

/// City and country shown on the health profile card.
/// Stored as one "City, Country" string so onboarding, the home card, and cloud sync share it.
enum UserLocationStore {
    static let defaultsKey = "user_location"

    static var current: String {
        UserDefaults.standard.string(forKey: defaultsKey) ?? ""
    }

    static func parts(from location: String) -> (city: String, country: String) {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.range(of: ", ", options: .backwards) else {
            return (trimmed, "")
        }
        let city = String(trimmed[..<separator.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let country = String(trimmed[separator.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (city, country)
    }

    static func formatted(city: String, country: String) -> String {
        let city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (city.isEmpty, country.isEmpty) {
        case (false, false): return "\(city), \(country)"
        case (false, true): return city
        case (true, false): return country
        case (true, true): return ""
        }
    }

    static func save(city: String, country: String, medicalAreas: [String]? = nil) {
        let location = formatted(city: city, country: country)
        UserDefaults.standard.set(location, forKey: defaultsKey)
        SyncQueueManager.shared.enqueuePreferencesUpload(
            UserPreferences(medicalAreas: medicalAreas ?? storedMedicalAreas(), location: location)
        )
    }

    private static func storedMedicalAreas() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: "onboarding_medical_areas"),
              let areas = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return areas
    }
}
