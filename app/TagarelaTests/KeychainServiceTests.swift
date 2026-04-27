import XCTest
@testable import Tagarela

final class KeychainServiceTests: XCTestCase {
    func test_setKey_thenGet_returnsKey() throws {
        let svc = FakeKeychainService()
        try svc.setOpenAIKey("sk-abc")
        XCTAssertEqual(try svc.openAIKey(), "sk-abc")
    }

    func test_setNil_deletesKey() throws {
        let svc = FakeKeychainService(initial: "sk-abc")
        try svc.setOpenAIKey(nil)
        XCTAssertNil(try svc.openAIKey())
    }

    func test_getWhenAbsent_returnsNil() throws {
        let svc = FakeKeychainService()
        XCTAssertNil(try svc.openAIKey())
    }

    /// Smoke test on real Keychain, isolated in distinct service/account.
    /// Uses com.tagarela.tests/openai-api-key-smoke to avoid touching production key.
    func test_live_setAndGet_smoke() throws {
        let live = KeychainServiceLive(
            service: "com.tagarela.tests",
            account: "openai-api-key-smoke")
        try live.setOpenAIKey("sk-tagarela-test")
        defer { _ = try? live.setOpenAIKey(nil) }
        XCTAssertEqual(try live.openAIKey(), "sk-tagarela-test")
    }
}
