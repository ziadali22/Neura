import Foundation
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome, privacy, goals, profile
    case emergency, biometrics, emergencyCard
    case healthKit, healthData, medical, documents

    var showsProgressBar: Bool { self != .welcome }

    static let progressTracked: [OnboardingStep] = [
        .privacy, .goals, .profile, .emergency,
        .biometrics, .emergencyCard, .healthKit, .medical, .documents
    ]
}

enum ProfileGender: String, CaseIterable, Identifiable {
    case male = "Male", female = "Female", other = "Other"
    var id: String { rawValue }
}

enum BloodType: String, CaseIterable, Identifiable {
    case aPos = "A+", aNeg = "A−", bPos = "B+", bNeg = "B−"
    case abPos = "AB+", abNeg = "AB−", oPos = "O+", oNeg = "O−"
    var id: String { rawValue }
}

enum UserGoal: String, CaseIterable, Identifiable {
    case trackRecords   = "Track medical records"
    case storeDocuments = "Store documents"
    case emergencyInfo  = "Emergency information"
    case shareReports   = "Share with doctors"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .trackRecords:   "doc.text.fill"
        case .storeDocuments: "folder.fill"
        case .emergencyInfo:  "staroflife.fill"
        case .shareReports:   "square.and.arrow.up.fill"
        }
    }
}

struct OnboardingState {
    var name: String = ""
    var dateOfBirth: Date? = nil
    var gender: ProfileGender? = nil
    var bloodType: BloodType? = nil
    var emergencyContactName: String = ""
    var emergencyContactPhone: String = ""
    var goals: Set<UserGoal> = []
    var medications: String = ""
    var allergies: String = ""
    var conditions: String = ""
}
