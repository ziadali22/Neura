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

    func heightDelta(from previous: GrowthEntry?) -> String? {
        guard let previous else { return nil }
        let change = heightCm - previous.heightCm
        guard change != 0 else { return nil }
        return change > 0 ? "+\(change)cm" : "\(change)cm"
    }

    func weightDelta(from previous: GrowthEntry?) -> String? {
        guard let previous else { return nil }
        let change = weightKg - previous.weightKg
        guard abs(change) >= 0.05 else { return nil }
        let amount = Self.formatWeight(abs(change)).replacingOccurrences(of: " kg", with: "")
        return change > 0 ? "+\(amount)kg" : "-\(amount)kg"
    }

    static let weightKilogramRange = 0...100
    static let weightGramStep = 100
    static let weightGramValues = Array(stride(from: 0, through: 900, by: weightGramStep))

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

    static func splitWeight(_ kg: Double) -> (kilograms: Int, grams: Int) {
        let maxKg = Double(weightKilogramRange.upperBound)
            + Double(weightGramValues.last ?? 0) / 1000
        let clamped = min(max(kg, 0), maxKg)
        let tenths = Int((clamped * 10).rounded())
        var kilograms = tenths / 10
        var grams = (tenths % 10) * weightGramStep
        if kilograms > weightKilogramRange.upperBound {
            kilograms = weightKilogramRange.upperBound
            grams = weightGramValues.last ?? 0
        }
        return (kilograms, grams)
    }

    static func combineWeight(kilograms: Int, grams: Int) -> Double {
        Double(kilograms) + Double(grams) / 1000
    }
}
