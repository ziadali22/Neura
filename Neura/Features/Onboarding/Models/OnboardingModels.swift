import Foundation
import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case stopSearching
    case storeAndShare
    case qrShare
    case statistics
    case recordsLocation
    case documentScan
    case privacySecurity
    case medicalAreas
    case profile, location, profileCardIntro, profileCard
    case emergency, biometrics, emergencyCard
    case healthKit, healthData, medical, documents, calculating

    /// Whether the top bar (back button + progress) is visible.
    var showsTopBar: Bool {
        switch self {
        case .stopSearching, .calculating: return false
        default: return true
        }
    }

    /// Whether the skip button is shown in the top bar.
    var isSkippable: Bool {
        switch self {
        case .welcome: return false
        default: return showsTopBar
        }
    }

    /// Whether the centered progress pill is shown within the top bar.
    var showsProgressBar: Bool {
        switch self {
        case .stopSearching, .storeAndShare, .statistics, .documentScan,
             .profileCardIntro, .qrShare, .privacySecurity, .welcome, .calculating:
            return false
        default: return true
        }
    }

    static let progressTracked: [OnboardingStep] = [
        .profile, .location, .biometrics, .healthKit, .profileCard
    ]

    /// The active flow in the order users see it — the source of truth for analytics
    /// screen numbers. Keep in sync with `OnboardingViewModel.nextStep(after:)`.
    /// Off-flow/retired steps are intentionally absent (they fire no analytics).
    static let analyticsFlow: [OnboardingStep] = [
        .stopSearching, .storeAndShare, .statistics, .documentScan,
        .profileCardIntro, .qrShare, .privacySecurity, .welcome,
        .profile, .location, .biometrics, .healthKit, .profileCard
    ]

    /// 1-based position in the visible flow, or `nil` for steps that aren't tracked
    /// (e.g. `.calculating` and off-flow steps).
    var analyticsScreenNumber: Int? {
        OnboardingStep.analyticsFlow.firstIndex(of: self).map { $0 + 1 }
    }
}

// MARK: - Profile enums

enum ProfileGender: String, CaseIterable, Identifiable {
    case male = "Male", female = "Female", other = "Other"
    var id: String { rawValue }
}

enum BloodType: String, CaseIterable, Identifiable {
    case aPos = "A+", aNeg = "A−", bPos = "B+", bNeg = "B−"
    case abPos = "AB+", abNeg = "AB−", oPos = "O+", oNeg = "O−"
    var id: String { rawValue }
}

// MARK: - Goals (kept for existing GoalsStep view)

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

// MARK: - Medical Areas

enum MedicalArea: String, CaseIterable, Identifiable {
    case cardiology       = "Cardiology"
    case dermatology      = "Dermatology"
    case dentistry        = "Dentistry"
    case endocrinology    = "Endocrinology"
    case gastroenterology = "Gastroenterology"
    case generalMedicine  = "General Medicine"
    case gynaecology      = "Gynaecology"
    case neurology        = "Neurology"
    case oncology         = "Oncology"
    case ophthalmology    = "Ophthalmology"
    case orthopedics      = "Orthopedics"
    case pediatrics       = "Pediatrics"
    case psychiatry       = "Psychiatry"
    case urology          = "Urology"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cardiology:       "heart"
        case .dermatology:      "sparkles"
        case .dentistry:        "mouth"
        case .endocrinology:    "leaf"
        case .gastroenterology: "fork.knife"
        case .generalMedicine:  "stethoscope"
        case .gynaecology:      "figure.stand.dress"
        case .neurology:        "brain.head.profile"
        case .oncology:         "cross.case"
        case .ophthalmology:    "eye"
        case .orthopedics:      "figure.walk"
        case .pediatrics:       "figure.child"
        case .psychiatry:       "brain"
        case .urology:          "drop"
        }
    }
}

// MARK: - State

struct OnboardingState {
    var name: String = ""
    var dateOfBirth: Date? = nil
    var gender: ProfileGender? = nil
    var bloodType: BloodType? = nil
    var emergencyContactName: String = ""
    var emergencyContactPhone: String = ""
    var goals: Set<UserGoal> = []
    var medicalAreas: Set<MedicalArea> = []
    var city: String = ""
    var country: String = ""
    var medications: String = ""
    var allergies: String = ""
    var conditions: String = ""
    var cardBackground: CardBackground = .default
}
