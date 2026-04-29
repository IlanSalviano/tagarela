import Foundation

protocol KeychainService: Sendable {
    func openAIKey() throws -> String?
    func setOpenAIKey(_ key: String?) throws // nil deletes
}

enum KeychainError: Error, Equatable {
    case osStatus(OSStatus)
    case invalidEncoding
}

#if DEBUG
/// Fake in-memory for tests. Never touches real Keychain.
/// Compiled only in DEBUG — not included in release binary.
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

/// Fake that simulates Keychain errors. For testing error handling.
final class ThrowingFakeKeychainService: KeychainService, @unchecked Sendable {
    private let error: KeychainError

    init(error: KeychainError = .osStatus(-1)) {
        self.error = error
    }

    func openAIKey() throws -> String? {
        throw error
    }

    func setOpenAIKey(_ key: String?) throws {
        throw error
    }
}
#endif
