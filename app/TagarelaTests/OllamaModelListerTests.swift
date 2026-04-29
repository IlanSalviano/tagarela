import XCTest
@testable import Tagarela

final class OllamaModelListerTests: XCTestCase {
    override func setUp() async throws { MockURLProtocol.responder = nil }
    override func tearDown() async throws { MockURLProtocol.responder = nil }

    private let baseURL = URL(string: "http://localhost:11434")!

    private func makeLister() -> OllamaModelLister {
        OllamaModelLister(session: MockURLProtocol.session(), baseURL: baseURL)
    }

    private func tagsBody(_ models: [String]) -> Data {
        let json: [String: Any] = [
            "models": models.map { ["name": $0, "modified_at": "2026-04-01T00:00:00Z"] }
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    func test_parseHappy_returnsModelNames() async throws {
        MockURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             self.tagsBody(["gemma4:e4b", "llama3.2:3b"]))
        }
        let lister = makeLister()
        let names = try await lister.availableModels()
        XCTAssertEqual(names, ["gemma4:e4b", "llama3.2:3b"])
    }

    func test_emptyList_returnsEmpty() async throws {
        MockURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             self.tagsBody([]))
        }
        let lister = makeLister()
        let names = try await lister.availableModels()
        XCTAssertEqual(names, [])
    }

    func test_malformed_throwsMalformed() async {
        MockURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("not json".utf8))
        }
        let lister = makeLister()
        do {
            _ = try await lister.availableModels()
            XCTFail("expected throw")
        } catch let e as OllamaModelListerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_offline_throwsOffline() async {
        MockURLProtocol.responder = { _ in throw URLError(.cannotConnectToHost) }
        let lister = makeLister()
        do {
            _ = try await lister.availableModels()
            XCTFail("expected throw")
        } catch let e as OllamaModelListerError {
            XCTAssertEqual(e, .offline)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
