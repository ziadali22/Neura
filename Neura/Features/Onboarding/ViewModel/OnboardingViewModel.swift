import SwiftUI
import Combine
import LocalAuthentication

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var state = OnboardingState()
    @Published var direction: Int = 1
    @Published var isComplete = false

    // Auth
    @Published var isSigningIn = false
    @Published var authError: String?

    // HealthKit
    @Published var healthKitStatus: HealthKitStatus = .notRequested
    @Published var healthKitData: HealthKitData?

    private let healthKitService = HealthKitService()

    enum HealthKitStatus { case notRequested, requesting, authorized, denied, unavailable }

    // MARK: - Progress

    var progress: Double {
        let tracked = OnboardingStep.progressTracked
        let step = currentStep == .healthData ? .healthKit : currentStep
        guard let idx = tracked.firstIndex(of: step) else { return 0 }
        return Double(idx + 1) / Double(tracked.count)
    }

    // MARK: - Navigation

    func advance() {
        direction = 1
        let next = nextStep(after: currentStep)
        if next == currentStep {
            finalize()
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                currentStep = next
            }
        }
    }

    func goBack() {
        direction = -1
        let prev = previousStep(before: currentStep)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep = prev
        }
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .welcome:         return .storeAndShare
        case .storeAndShare:   return .statistics
        case .statistics:      return .recordsLocation
        case .recordsLocation: return .documentScan
        case .documentScan:    return .privacySecurity
        case .privacySecurity: return .medicalAreas
        case .medicalAreas:    return .profile
        case .profile:         return .location
        case .location:          return .profileCardIntro
        case .profileCardIntro:  return .profileCard
        case .profileCard:       return .emergency
        case .emergency:       return .biometrics
        case .biometrics:      return .emergencyCard
        case .emergencyCard:   return .healthKit
        case .healthKit:
            if healthKitStatus == .authorized, healthKitData?.hasAnyData == true { return .healthData }
            return .medical
        case .healthData:      return .medical
        case .medical:         return .documents
        case .documents:       return .calculating
        case .calculating:     return .calculating // sentinel — caller handles completion
        }
    }

    private func previousStep(before step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .welcome:         return .welcome
        case .storeAndShare:   return .welcome
        case .statistics:      return .storeAndShare
        case .recordsLocation: return .statistics
        case .documentScan:    return .recordsLocation
        case .privacySecurity: return .documentScan
        case .medicalAreas:    return .privacySecurity
        case .profile:         return .medicalAreas
        case .location:        return .profile
        case .profileCardIntro: return .location
        case .profileCard:      return .profileCardIntro
        case .emergency:       return .profileCard
        case .biometrics:      return .emergency
        case .emergencyCard:   return .biometrics
        case .healthKit:       return .emergencyCard
        case .healthData:      return .healthKit
        case .medical:
            if healthKitStatus == .authorized, healthKitData?.hasAnyData == true { return .healthData }
            return .healthKit
        case .documents:       return .medical
        case .calculating:     return .documents
        }
    }

    // MARK: - HealthKit

    func requestHealthKit() {
        Task {
            healthKitStatus = .requesting
            let result = await healthKitService.requestAuthorization()
            switch result {
            case .success:
                let data = await healthKitService.fetchData()
                healthKitData = data
                healthKitStatus = .authorized
            case .denied:
                healthKitStatus = .denied
            case .unavailable:
                healthKitStatus = .unavailable
            }
            advance()
        }
    }

    // MARK: - Biometrics

    func requestBiometrics() async {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            advance(); return
        }
        _ = try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Protect your health profile"
        )
        advance()
    }

    var biometricLabel: String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return "Passcode" }
        return context.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    var biometricIcon: String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return "lock.fill" }
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }

    // MARK: - Auth

    func signInWithApple() {
        guard !isSigningIn else { return }
        isSigningIn = true
        authError = nil
        Task {
            do {
                try await AuthService.shared.signInWithApple()
                advance()
            } catch {
                if !isCancellation(error) { authError = error.localizedDescription }
            }
            isSigningIn = false
        }
    }

    func signInWithGoogle() {
        guard !isSigningIn else { return }
        isSigningIn = true
        authError = nil
        Task {
            do {
                try await AuthService.shared.signInWithGoogle()
                advance()
            } catch {
                if !isCancellation(error) { authError = error.localizedDescription }
            }
            isSigningIn = false
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        // ASAuthorizationError.canceled = 1001
        // GIDSignInError.canceled = -5
        return (nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" && nsError.code == 1001)
            || (nsError.domain == "com.google.GIDSignIn" && nsError.code == -5)
    }

    // MARK: - Complete

    func finalize() {
        saveProfile()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.4)) { isComplete = true }
    }

    private func saveProfile() {
        let dob = state.dateOfBirth.map {
            $0.formatted(.dateTime.day().month(.wide).year())
        } ?? ""

        let contact: String
        switch (state.emergencyContactName.isEmpty, state.emergencyContactPhone.isEmpty) {
        case (true, true):   contact = ""
        case (false, true):  contact = state.emergencyContactName
        case (true, false):  contact = state.emergencyContactPhone
        case (false, false): contact = "\(state.emergencyContactName) · \(state.emergencyContactPhone)"
        }

        let gender = state.gender?.rawValue ?? healthKitData?.biologicalSex ?? ""

        let generalData = HealthProfile.GeneralData(
            fullName: state.name,
            dateOfBirth: dob,
            gender: gender,
            height: healthKitData?.height ?? "",
            weight: healthKitData?.weight ?? "",
            bloodType: state.bloodType?.rawValue ?? "",
            insuranceStatus: "",
            emergencyContact: contact
        )

        var profile = HealthProfile.default
        profile.generalData = generalData

        func fill(_ text: String, section keyword: String) {
            let entries = text.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { HealthProfile.HealthSection.Entry(text: $0) }
            guard !entries.isEmpty,
                  let idx = profile.sections.firstIndex(where: { $0.title.lowercased().contains(keyword) }) else { return }
            profile.sections[idx].entries = entries
        }

        fill(state.medications, section: "medication")
        fill(state.allergies,   section: "allerg")
        fill(state.conditions,  section: "condition")

        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "health_profile_data")
        }

        // Persist selected medical areas
        let areas = state.medicalAreas.map(\.rawValue)
        if let data = try? JSONEncoder().encode(areas) {
            UserDefaults.standard.set(data, forKey: "onboarding_medical_areas")
        }

        // Persist card background
        state.cardBackground.save()

        // Persist location
        let location: String
        switch (state.city.trimmingCharacters(in: .whitespaces).isEmpty,
                state.country.trimmingCharacters(in: .whitespaces).isEmpty) {
        case (false, false): location = "\(state.city), \(state.country)"
        case (false, true):  location = state.city
        case (true, false):  location = state.country
        case (true, true):   location = ""
        }
        UserDefaults.standard.set(location, forKey: "user_location")
    }
}
