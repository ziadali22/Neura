import SwiftUI
import Combine

// MARK: - Share State

enum ShareState: Equatable {
    case idle
    case uploading
    case ready(URL, Date)
    case expired
    case error(String)

    static func == (lhs: ShareState, rhs: ShareState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.uploading, .uploading), (.expired, .expired):
            return true
        case (.ready(let lURL, let lDate), .ready(let rURL, let rDate)):
            return lURL == rURL && lDate == rDate
        case (.error(let lMsg), .error(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

// MARK: - Share Document ViewModel

@MainActor
final class ShareDocumentViewModel: ObservableObject {
    @Published var state: ShareState = .idle
    @Published var qrImage: UIImage?
    @Published var remainingTime: String = ""
    @Published var isUrgent = false

    private var timerCancellable: AnyCancellable?
    private var expiresAt: Date?
    private var currentURL: URL?

    private let uploadService: CloudUploadService
    private let fileData: Data
    private let filename: String
    private let mimeType: String

    init(fileData: Data, filename: String, mimeType: String, uploadService: CloudUploadService = FirebaseUploadService.shared) {
        self.fileData = fileData
        self.filename = filename
        self.mimeType = mimeType
        self.uploadService = uploadService
    }

    // MARK: - Actions

    func startSharing() {
        state = .uploading

        Task {
            do {
                let link = try await uploadService.upload(data: fileData, filename: filename, mimeType: mimeType)
                let qr = UIImage.qrCode(from: link.url.absoluteString, size: 200)

                self.expiresAt = link.expiresAt
                self.currentURL = link.url
                self.qrImage = qr
                self.state = .ready(link.url, link.expiresAt)
                self.startCountdown()
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func regenerateLink() {
        stopCountdown()
        startSharing()
    }

    func copyLink() {
        guard let url = currentURL else { return }
        UIPasteboard.general.string = url.absoluteString
    }

    // MARK: - Countdown Timer

    private func startCountdown() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRemainingTime()
            }
        updateRemainingTime()
    }

    private func stopCountdown() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func updateRemainingTime() {
        guard let expiresAt else { return }

        let remaining = expiresAt.timeIntervalSinceNow
        guard remaining > 0 else {
            stopCountdown()
            state = .expired
            remainingTime = "Expired"
            isUrgent = false
            return
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            remainingTime = "Expires in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            remainingTime = "Expires in \(minutes)m"
        } else {
            let seconds = Int(remaining) % 60
            remainingTime = "Expires in \(seconds)s"
        }

        isUrgent = remaining < 600 // < 10 minutes
    }

    deinit {
        timerCancellable?.cancel()
    }
}
