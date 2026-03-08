import Foundation

struct HealthProfile: Codable {
    var generalData: GeneralData
    var sections: [HealthSection]
    var lastUpdated: Date

    struct GeneralData: Codable {
        var fullName: String
        var dateOfBirth: String
        var gender: String
        var height: String
        var weight: String
        var bloodType: String
        var insuranceStatus: String
    }

    struct HealthSection: Identifiable, Codable {
        var id: UUID
        var title: String
        var entries: [Entry]

        struct Entry: Identifiable, Codable {
            var id: UUID
            var text: String

            init(text: String) {
                self.id = UUID()
                self.text = text
            }
        }

        init(title: String, entries: [Entry] = []) {
            self.id = UUID()
            self.title = title
            self.entries = entries
        }
    }

    static let `default` = HealthProfile(
        generalData: GeneralData(
            fullName: "",
            dateOfBirth: "",
            gender: "",
            height: "",
            weight: "",
            bloodType: "",
            insuranceStatus: ""
        ),
        sections: [
            HealthSection(title: "Known Conditions"),
            HealthSection(title: "Known Symptoms"),
            HealthSection(title: "Allergies"),
            HealthSection(title: "Medication & Supplements"),
            HealthSection(title: "Family History"),
            HealthSection(title: "Mobility Status")
        ],
        lastUpdated: Date()
    )

    static let sample = HealthProfile(
        generalData: GeneralData(
            fullName: "Elena Rossi",
            dateOfBirth: "02 Jan 2002 (24)",
            gender: "Female",
            height: "1,67m",
            weight: "54kg",
            bloodType: "",
            insuranceStatus: "Insured"
        ),
        sections: [
            HealthSection(title: "Known Conditions"),
            HealthSection(title: "Known Symptoms", entries: [
                .init(text: "Persistent fatigue"),
                .init(text: "Intermittent dizziness"),
                .init(text: "Joint stiffness"),
                .init(text: "Recurrent headaches")
            ]),
            HealthSection(title: "Allergies", entries: [
                .init(text: "Penicillin")
            ]),
            HealthSection(title: "Medication & Supplements", entries: [
                .init(text: "Vitamin D")
            ]),
            HealthSection(title: "Family History", entries: [
                .init(text: "Mother: Rheumatoid Arthritis"),
                .init(text: "Father: Hypertension")
            ]),
            HealthSection(title: "Mobility Status")
        ],
        lastUpdated: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
    )
}
