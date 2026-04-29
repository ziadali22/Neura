import Foundation
import CryptoKit

// MARK: - Encryption Service

enum EncryptionService {

    /// Encrypts data using AES-GCM. Returns the random IV (nonce) and ciphertext+tag combined.
    static func encrypt(_ data: Data, key: SymmetricKey) throws -> (iv: Data, ciphertext: Data) {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
        // ciphertext + 16-byte tag stored together
        let combined = sealed.ciphertext + sealed.tag
        return (Data(nonce), combined)
    }

    /// Decrypts data encrypted by `encrypt(_:key:)`.
    static func decrypt(ciphertext: Data, iv: Data, key: SymmetricKey) throws -> Data {
        guard ciphertext.count > 16 else { throw EncryptionError.invalidCiphertext }
        let tagStart = ciphertext.index(ciphertext.endIndex, offsetBy: -16)
        let body = ciphertext[..<tagStart]
        let tag  = ciphertext[tagStart...]
        let nonce = try AES.GCM.Nonce(data: iv)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: body, tag: tag)
        return try AES.GCM.open(box, using: key)
    }
}

// MARK: - Encryption Error

enum EncryptionError: LocalizedError {
    case invalidCiphertext

    var errorDescription: String? {
        "The file is corrupted or could not be decrypted."
    }
}
