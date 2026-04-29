import Foundation

// MARK: - Expiring Link

struct ExpiringLink {
    let url: URL
    let expiresAt: Date
}

// MARK: - Upload Error

enum CloudUploadError: LocalizedError {
    case notConfigured
    case fileTooLarge(Int)
    case uploadFailed(String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase is not configured. Please set up your project in FirebaseConfig.swift"
        case .fileTooLarge(let size):
            let mb = size / (1024 * 1024)
            return "File is too large (\(mb)MB). Maximum size is 10MB."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Cloud Upload Service Protocol

protocol CloudUploadService {
    func upload(data: Data, filename: String, mimeType: String) async throws -> ExpiringLink
}

// MARK: - Firebase Upload Service

final class FirebaseUploadService: CloudUploadService {
    static let shared = FirebaseUploadService()
    private let session = URLSession.shared

    private init() {}

    func upload(data: Data, filename: String, mimeType: String) async throws -> ExpiringLink {
        guard FirebaseConfig.isConfigured else {
            throw CloudUploadError.notConfigured
        }

        guard data.count <= FirebaseConfig.maxFileSizeBytes else {
            throw CloudUploadError.fileTooLarge(data.count)
        }

        // Step 1: Upload file to Firebase Storage via REST API
        let fileId = UUID().uuidString
        let storagePath = "\(FirebaseConfig.sharedFolderPrefix)/\(fileId)/\(filename)"
        let encodedPath = storagePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? storagePath

        guard let uploadURL = URL(string: "\(FirebaseConfig.uploadURL)?uploadType=media&name=\(encodedPath)&key=\(FirebaseConfig.apiKey)") else {
            throw CloudUploadError.invalidResponse
        }

        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = data

        let (uploadData, uploadResponse): (Data, URLResponse)
        do {
            (uploadData, uploadResponse) = try await session.data(for: uploadRequest)
        } catch {
            throw CloudUploadError.networkError(error)
        }

        guard let httpResponse = uploadResponse as? HTTPURLResponse else {
            throw CloudUploadError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: uploadData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudUploadError.uploadFailed(message)
        }

        // Step 2: Call Cloud Function to get short redirect URL
        guard let shareURL = URL(string: FirebaseConfig.shareURL) else {
            throw CloudUploadError.invalidResponse
        }

        var shareRequest = URLRequest(url: shareURL)
        shareRequest.httpMethod = "POST"
        shareRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let shareBody: [String: Any] = [
            "fileId": fileId,
            "filename": filename,
            "storagePath": storagePath
        ]
        shareRequest.httpBody = try JSONSerialization.data(withJSONObject: shareBody)

        let (shareData, shareResponse): (Data, URLResponse)
        do {
            (shareData, shareResponse) = try await session.data(for: shareRequest)
        } catch {
            throw CloudUploadError.networkError(error)
        }

        guard let shareHttpResponse = shareResponse as? HTTPURLResponse else {
            throw CloudUploadError.invalidResponse
        }

        guard (200...299).contains(shareHttpResponse.statusCode) else {
            let message = String(data: shareData, encoding: .utf8) ?? "HTTP \(shareHttpResponse.statusCode)"
            throw CloudUploadError.uploadFailed("Cloud Function error: \(message)")
        }

        guard let json = try JSONSerialization.jsonObject(with: shareData) as? [String: Any],
              let shortURLString = json["url"] as? String,
              let shortURL = URL(string: shortURLString),
              let expiresAtTimestamp = json["expiresAt"] as? TimeInterval else {
            throw CloudUploadError.invalidResponse
        }

        let expiresAt = Date(timeIntervalSince1970: expiresAtTimestamp)

        return ExpiringLink(url: shortURL, expiresAt: expiresAt)
    }

    // MARK: - MIME Type Helper

    static func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
}
