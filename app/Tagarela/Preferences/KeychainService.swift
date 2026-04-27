import Foundation

protocol KeychainService: Sendable {
    func openAIKey() throws -> String?
    func setOpenAIKey(_ key: String?) throws // nil deletes
}

enum KeychainError: Error, Equatable {
    case osStatus(OSStatus)
    case invalidEncoding
}

/// Fake in-memory for tests. Never touches real Keychain.
final class FakeKeychainService: KeychainService, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    init(initial: String? = nil) {
        self.stored = initial
    }

    func openAIKey() throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func setOpenAIKey(_ key: String?) throws {
        lock.lock(); defer { lock.unlock() }
        stored = key
    }
}
