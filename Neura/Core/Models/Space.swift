import Foundation

struct Space: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var isDefault: Bool
    var isArchived: Bool
    /// Filename in AccountAvatarStore, or nil if no photo has been set.
    var avatarFilename: String?
    /// Canonical `Relationship.rawValue` (e.g. "child"), or a legacy localized
    /// label from before relationships were stored canonically. Nil if unset.
    var relationship: String?

    private static let colorPalette = ["FF5A00", "3498DB", "9B59B6", "27AE60", "E74C3C", "1ABC9C"]

    /// Deterministic fallback color derived from the id — stable across
    /// launches and devices, used only when no avatar photo is set. Not
    /// stored: old persisted data with a "colorHex" JSON key simply has that
    /// key ignored on decode (Codable synthesis no longer looks for it).
    var colorHex: String {
        let b = id.uuid
        let seed = Int(b.0) &+ Int(b.4) &+ Int(b.8) &+ Int(b.12)
        return Self.colorPalette[seed % Self.colorPalette.count]
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        isDefault: Bool = false,
        isArchived: Bool = false,
        avatarFilename: String? = nil,
        relationship: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.isArchived = isArchived
        self.avatarFilename = avatarFilename
        self.relationship = relationship
    }
}
