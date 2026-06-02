import SwiftUI
import Combine
import LocalAuthentication
import FirebaseAuth

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .stopSearching
    @Published var state = OnboardingState()
    @Published var direction: Int = 1
    @Published var isComplete = false

    // Auth
    @Published var isSigningIn = false
    @Published var authError: String?
    private var isReturningUser = false

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
        // Active flow
        case .stopSearching:    return .storeAndShare
        case .storeAndShare:    return .statistics
        case .statistics:       return .documentScan
        case .documentScan:     return .profileCardIntro
        case .profileCardIntro: return .qrShare
        case .qrShare:          return .privacySecurity
        case .privacySecurity:  return .welcome
        case .welcome:          return .profile
        case .profile:          return .location
        case .location:         return .biometrics
        case .biometrics:       return .healthKit
        case .healthKit:        return .profileCard
        case .profileCard:      return .calculating
        case .calculating:      return .calculating // sentinel — caller handles completion
        // Retained but off-flow steps
        case .recordsLocation:  return .documentScan
        case .medicalAreas:     return .profile
        case .emergency:        return .biometrics
        case .emergencyCard:    return .healthKit
        case .healthData:       return .medical
        case .medical:          return .documents
        case .documents:        return .calculating
        }
    }

    private func previousStep(before step: OnboardingStep) -> OnboardingStep {
        switch step {
        // Active flow
        case .stopSearching:    return .stopSearching // first step
        case .storeAndShare:    return .stopSearching
        case .statistics:       return .storeAndShare
        case .documentScan:     return .statistics
        case .profileCardIntro: return .documentScan
        case .qrShare:          return .profileCardIntro
        case .privacySecurity:  return .qrShare
        case .welcome:          return .privacySecurity
        case .profile:          return .welcome
        case .location:         return .profile
        case .biometrics:       return .location
        case .healthKit:        return .biometrics
        case .profileCard:      return .healthKit
        case .calculating:      return .profileCard
        // Retained but off-flow steps
        case .recordsLocation:  return .statistics
        case .medicalAreas:     return .privacySecurity
        case .emergency:        return .profileCard
        case .emergencyCard:    return .biometrics
        case .healthData:       return .healthKit
        case .medical:          return .healthKit
        case .documents:        return .medical
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
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return "faceid" }
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
                await checkReturningUser()
                isReturningUser ? finalize() : advance()
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
                await checkReturningUser()
                isReturningUser ? finalize() : advance()
            } catch {
                if !isCancellation(error) { authError = error.localizedDescription }
            }
            isSigningIn = false
        }
    }

    private func checkReturningUser() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        isReturningUser = await AuthService.shared.hasExistingCloudData(uid: uid)
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
        // Returning users already have their profile in the cloud; skip overwriting
        // so performInitialRestore can write the real data without conflict.
        guard !isReturningUser else { return }

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
            myPhoneNumber: "",
            emergencyContactName: state.emergencyContactName,
            emergencyContactNumber: state.emergencyContactPhone
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
