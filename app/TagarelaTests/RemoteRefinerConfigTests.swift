import XCTest
@testable import Tagarela

final class RemoteRefinerConfigTests: XCTestCase {
    func test_gpt54_returns200k() {
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "gpt-5.4-mini"), 200_000)
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "GPT-5.4"), 200_000) // case insensitive
    }

    func test_qwen3DefaultModel_returns32k() {
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "qwen3.5:9b-nvfp4"), 32_768)
    }

    func test_llama32_returns128k() {
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "llama3.2:3b"), 128_000)
    }

    func test_unknownModel_returnsConservativeFallback() {
        XCTAssertEqual(
            RemoteRefinerConfig.contextWindow(for: "gemma:2b"),
            RemoteRefinerConfig.conservativeFallback)
    }

    func test_usableFraction_isPointEight() {
        XCTAssertEqual(RemoteRefinerConfig.usableFraction, 0.8, accuracy: 0.001)
    }
}
