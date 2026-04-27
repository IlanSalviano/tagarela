import XCTest
@testable import Tagarela

final class TokenCounterTests: XCTestCase {
    func test_emptyString_returnsAtLeast1() {
        XCTAssertEqual(TokenCounter.estimate(""), 1)
    }

    func test_8chars_returns2() {
        XCTAssertEqual(TokenCounter.estimate("abcdefgh"), 2)
    }

    func test_largeText_estimateBatesMargem() {
        let s = String(repeating: "a", count: 10_000)
        let est = TokenCounter.estimate(s)
        XCTAssertGreaterThan(est, 2000)
        XCTAssertLessThan(est, 3000)
    }
}
