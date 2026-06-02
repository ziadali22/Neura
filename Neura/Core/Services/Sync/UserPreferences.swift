import Foundation

/// Onboarding-set preferences that should survive a reinstall:
/// the user's selected medical areas and their location string.
struct UserPreferences: Codable {
    var medicalAreas: [String]
    var location: String
}
