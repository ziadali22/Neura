import Foundation

struct GrowthEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var heightCm: Int
    var weightKg: Double
    var photoFilename: String?
    var notes: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        heightCm: Int,
        weightKg: Double,
        photoFilename: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.photoFilename = photoFilename
        self.notes = notes
    }

    var heightLabel: String { "\(heightCm) cm" }

    var weightLabel: String { Self.formatWeight(weightKg) }

    static func formatWeight(_ kg: Double) -> String {
        kg.rounded() == kg
            ? "\(Int(kg)) kg"
            : String(format: "%.1f kg", kg)
    }

    static func parseHeightCm(_ value: String) -> Int? {
        let digits = value.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(digits)
    }

    static func parseWeightKg(_ value: String) -> Double? {
        let trimmed = value
            .lowercased()
            .replacingOccurrences(of: "kg", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed)
    }
}
