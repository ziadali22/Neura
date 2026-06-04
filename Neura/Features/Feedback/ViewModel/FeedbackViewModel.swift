import Combine
import FirebaseAuth
import Foundation
import SwiftUI

// MARK: - Feedback View Model

@MainActor
final class FeedbackViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case submitting
        case success
        case error(String)
    }

    @Published var email: String = ""
    @Published var message: String = ""
    @Published private(set) var state: State = .idle

    private let service: FeedbackService

    init(service: FeedbackService = .shared) {
        self.service = service
    }

    // MARK: - Validation

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    var isMessageValid: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var isValid: Bool { isEmailValid && isMessageValid }

    var isSubmitting: Bool { state == .submitting }

    // MARK: - Submit

    func submit() async {
        guard isValid, !isSubmitting else { return }
        state = .submitting

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = AuthService.shared.currentUser?.uid

        do {
            try await service.submit(email: trimmedEmail, message: trimmedMessage, uid: uid)
            state = .success
            HapticManager.success()
        } catch {
            state = .error(L10n.Profile.Feedback.errorMessage)
            HapticManager.error()
        }
    }
}
