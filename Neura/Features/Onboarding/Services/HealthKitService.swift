import Foundation
import HealthKit

struct HealthKitData {
    var height: String?
    var weight: String?
    var dateOfBirth: Date?
    var biologicalSex: String?
    var hasAnyData: Bool { height != nil || weight != nil || biologicalSex != nil }
}

final class HealthKitService {
    private let store = HKHealthStore()

    enum AuthResult { case success, denied, unavailable }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> AuthResult {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.height),
            HKQuantityType(.bodyMass),
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex)
        ]
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return .success
        } catch {
            return .denied
        }
    }

    func fetchData() async -> HealthKitData {
        var data = HealthKitData()
        if let sample = await fetchLatest(HKQuantityType(.height)) {
            let cm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            data.height = String(format: "%.0f cm", cm)
        }
        if let sample = await fetchLatest(HKQuantityType(.bodyMass)) {
            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            data.weight = String(format: "%.1f kg", kg)
        }
        data.dateOfBirth = try? Calendar.current.date(from: store.dateOfBirthComponents())
        if let sex = try? store.biologicalSex() {
            switch sex.biologicalSex {
            case .male:   data.biologicalSex = "Male"
            case .female: data.biologicalSex = "Female"
            case .other:  data.biologicalSex = "Other"
            default: break
            }
        }
        return data
    }

    private func fetchLatest(_ type: HKQuantityType) async -> HKQuantitySample? {
        await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, s, _ in
                cont.resume(returning: s?.first as? HKQuantitySample)
            }
            store.execute(q)
        }
    }
}
