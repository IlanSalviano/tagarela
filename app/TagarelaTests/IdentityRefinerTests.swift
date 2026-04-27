import XCTest
@testable import Tagarela

final class IdentityRefinerTests: XCTestCase {
    func test_returnsInputUnchanged() async throws {
        let r = IdentityRefiner()
        let out = try await r.refine("foo bar", style: "qualquer")
        XCTAssertEqual(out, "foo bar")
    }

    func test_kindIsNone() {
        XCTAssertEqual(IdentityRefiner().kind, .none)
    }
}
