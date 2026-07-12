import Foundation

struct Space: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var isDefault: Bool
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        createdAt: Date = Date(),
        isDefault: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.isArchived = isArchived
    }
}
