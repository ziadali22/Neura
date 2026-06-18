import Foundation

/// A single un-synced operation, durably recorded so it survives app termination.
struct PendingSyncOp: Codable, Hashable {
    enum Kind: String, Codable {
        case documentUpload
        case documentMetadata
        case documentDelete
        case profileUpload
        case preferencesUpload
    }
    let kind: Kind
    /// Document UUID string for document ops; nil for profile/preferences (single-doc).
    let id: String?
}

/// Persists pending sync operations to Application Support so failed or interrupted
/// uploads are retried on the next drain.
@MainActor
final class PendingSyncStore {
    static let shared = PendingSyncStore()

    private let fileURL: URL
    private var ops: Set<PendingSyncOp>

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("pending_sync.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Set<PendingSyncOp>.self, from: data) {
            ops = decoded
        } else {
            ops = []
        }
    }

    var all: [PendingSyncOp] { Array(ops) }

    func add(_ op: PendingSyncOp) {
        // A delete supersedes a pending upload/metadata for the same document.
        if op.kind == .documentDelete, let id = op.id {
            ops = ops.filter {
                !($0.id == id && ($0.kind == .documentUpload || $0.kind == .documentMetadata))
            }
        }
        ops.insert(op)
        persist()
    }

    func remove(_ op: PendingSyncOp) {
        ops.remove(op)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(ops) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
