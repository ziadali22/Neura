import Foundation
import os

/// Centralized logging for the cloud sync subsystem.
/// View in Console.app / Xcode by filtering subsystem "com.neura.sync".
enum SyncLog {
    private static let logger = Logger(subsystem: "com.neura.sync", category: "sync")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func success(_ message: String) {
        logger.info("✅ \(message, privacy: .public)")
    }

    static func failure(_ message: String, error: Error) {
        logger.error("❌ \(message, privacy: .public) — \(error.localizedDescription, privacy: .public)")
    }
}
