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
        var emergencyContact: String

        init(fullName: String, dateOfBirth: String, gender: String, height: String, weight: String, bloodType: String, insuranceStatus: String, emergencyContact: String = "") {
            self.fullName = fullName
            self.dateOfBirth = dateOfBirth
            self.gender = gender
            self.height = height
            self.weight = weight
            self.bloodType = bloodType
            self.insuranceStatus = insuranceStatus
            self.emergencyContact = emergencyContact
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fullName = try container.decode(String.self, forKey: .fullName)
            dateOfBirth = try container.decode(String.self, forKey: .dateOfBirth)
            gender = try container.decode(String.self, forKey: .gender)
            height = try container.decode(String.self, forKey: .height)
            weight = try container.decode(String.self, forKey: .weight)
            bloodType = try container.decode(String.self, forKey: .bloodType)
            insuranceStatus = try container.decode(String.self, forKey: .insuranceStatus)
            emergencyContact = try container.decodeIfPresent(String.self, forKey: .emergencyContact) ?? ""
        }
    }

    struct HealthSection: Identifiable, Codable {
        var id: UUID
        var title: String
        var entries: [Entry]

        struct Entry: Identifiable, Codable, Hashable {
            var id: UUID
            var text: String
            var field1: String
            var field2: String
            var notes: String

            init(text: String, field1: String = "", field2: String = "", notes: String = "") {
                self.id = UUID()
                self.text = text
                self.field1 = field1
                self.field2 = field2
                self.notes = notes
            }

            // Backward-compatible decoding
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(UUID.self, forKey: .id)
                text = try container.decode(String.self, forKey: .text)
                field1 = try container.decodeIfPresent(String.self, forKey: .field1) ?? ""
                field2 = try container.decodeIfPresent(String.self, forKey: .field2) ?? ""
                notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
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
            HealthSection(title: "Medication & Supplements"),
            HealthSection(title: "Allergies"),
            HealthSection(title: "Reported Symptoms"),
            HealthSection(title: "Family History"),
        ],
        lastUpdated: Date()
    )

    static let sample = HealthProfile(
        generalData: GeneralData(
            fullName: "Elena Rossi",
            dateOfBirth: "02 Jan 2002 (24)",
            gender: "Female",
            height: "1,65m",
            weight: "54kg",
            bloodType: "",
            insuranceStatus: "Insured"
        ),
        sections: [
            HealthSection(title: "Known Conditions", entries: [
                .init(text: "Disease S", field1: "Since 2022", field2: "Ongoing treatment")
            ]),
            HealthSection(title: "Medication & Supplements", entries: [
                .init(text: "Vitamin D", field1: "1000 IU", field2: "Daily"),
                .init(text: "Omega 3", field1: "500mg", field2: "Daily")
            ]),
            HealthSection(title: "Allergies", entries: [
                .init(text: "Ambrosia", field1: "Swelling, rash", field2: "EpiPen"),
                .init(text: "Pollen", field1: "Swelling, rash", field2: "EpiPen")
            ]),
            HealthSection(title: "Reported Symptoms", entries: [
                .init(text: "Persistent fatigue"),
                .init(text: "Intermittent dizziness"),
                .init(text: "Joint stiffness"),
                .init(text: "Recurrent headaches")
            ]),
            HealthSection(title: "Family History", entries: [
                .init(text: "Mother: Rheumatoid Arthritis"),
                .init(text: "Father: Hypertension")
            ])
        ],
        lastUpdated: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
    )
}

// MARK: - Section Field Labels

struct SectionFieldConfig {
    let addTitle: String
    let nameLabel: String
    let namePlaceholder: String
    let field1Label: String
    let field1Placeholder: String
    let field2Label: String
    let field2Placeholder: String

    static func forSection(_ title: String) -> SectionFieldConfig {
        switch title.lowercased() {
        case let t where t.contains("allerg"):
            return .init(
                addTitle: "Add Allergy",
                nameLabel: "Allergy Name",
                namePlaceholder: "E.g. peanuts",
                field1Label: "Symptoms",
                field1Placeholder: "E.g. swelling, rash",
                field2Label: "Treatment",
                field2Placeholder: "E.g. antihistamine, EpiPen"
            )
        case let t where t.contains("medication") || t.contains("supplement"):
            return .init(
                addTitle: "Add Medication",
                nameLabel: "Medication Name",
                namePlaceholder: "E.g. Vitamin D",
                field1Label: "Dosage",
                field1Placeholder: "E.g. 1000 IU",
                field2Label: "Frequency",
                field2Placeholder: "E.g. daily"
            )
        case let t where t.contains("condition"):
            return .init(
                addTitle: "Add Condition",
                nameLabel: "Condition Name",
                namePlaceholder: "E.g. diabetes",
                field1Label: "Diagnosed",
                field1Placeholder: "E.g. since 2020",
                field2Label: "Treatment",
                field2Placeholder: "E.g. insulin therapy"
            )
        case let t where t.contains("symptom"):
            return .init(
                addTitle: "Add Symptom",
                nameLabel: "Symptom Name",
                namePlaceholder: "E.g. persistent fatigue",
                field1Label: "Severity",
                field1Placeholder: "E.g. moderate",
                field2Label: "Duration",
                field2Placeholder: "E.g. 3 months"
            )
        case let t where t.contains("family"):
            return .init(
                addTitle: "Add Family History",
                nameLabel: "Condition",
                namePlaceholder: "E.g. hypertension",
                field1Label: "Relation",
                field1Placeholder: "E.g. mother",
                field2Label: "Details",
                field2Placeholder: "E.g. diagnosed at 50"
            )
        default:
            return .init(
                addTitle: "Add Entry",
                nameLabel: "Name",
                namePlaceholder: "Enter name",
                field1Label: "Details",
                field1Placeholder: "Enter details",
                field2Label: "Additional Info",
                field2Placeholder: "Enter info"
            )
        }
    }
}
