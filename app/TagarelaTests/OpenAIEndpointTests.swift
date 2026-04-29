import XCTest
@testable import Tagarela

final class OpenAIEndpointTests: XCTestCase {
    func test_codableRoundTrip() throws {
        let original = OpenAIEndpoint(provider: .openrouter,
                                       baseURL: URL(string: "https://openrouter.ai/api/v1")!)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_defaultURL_forEachProvider_matchesExpected() {
        XCTAssertEqual(OpenAIEndpointDefaults.defaultURL(for: .official),
                       URL(string: "https://api.openai.com/v1"))
        XCTAssertEqual(OpenAIEndpointDefaults.defaultURL(for: .openrouter),
                       URL(string: "https://openrouter.ai/api/v1"))
        XCTAssertEqual(OpenAIEndpointDefaults.defaultURL(for: .lmstudio),
                       URL(string: "http://localhost:1234/v1"))
        XCTAssertNil(OpenAIEndpointDefaults.defaultURL(for: .custom))
    }

    func test_allProvidersAreCaseIterable() {
        XCTAssertEqual(Set(OpenAIProvider.allCases),
                       Set([.official, .openrouter, .lmstudio, .custom]))
    }
}
