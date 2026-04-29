import XCTest
@testable import Tagarela

final class OllamaRefinerTests: XCTestCase {
    override func setUp() async throws { MockURLProtocol.responder = nil }
    override func tearDown() async throws { MockURLProtocol.responder = nil }

    private let baseURL = URL(string: "http://localhost:11434")!

    private func httpResp(_ status: Int, path: String = "/api/chat") -> HTTPURLResponse {
        HTTPURLResponse(url: baseURL.appendingPathComponent(path),
                        statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func successBody(_ content: String) -> Data {
        let json: [String: Any] = ["message": ["content": content]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeRefiner() -> (OllamaRefiner, OllamaHealthChecker) {
        let session = MockURLProtocol.session()
        let hc = OllamaHealthChecker(session: session, baseURL: baseURL)
        let r = OllamaRefiner(session: session, baseURL: baseURL,
                              model: "qwen3.5:9b-nvfp4", timeoutSec: 30, healthChecker: hc)
        return (r, hc)
    }

    func test_healthCheckOffline_skipsChatAndThrowsOffline() async {
        nonisolated(unsafe) var chatCalled = false
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                throw URLError(.cannotConnectToHost)
            }
            chatCalled = true
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"message":{"content":"nope"}}"#.utf8))
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .networkOffline)
            XCTAssertFalse(chatCalled, "chat foi chamado mesmo com health offline")
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_healthCheckOnline_proceedsToChat() async throws {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data("{}".utf8))
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"message":{"content":"refinado"}}"#.utf8))
        }
        let (r, _) = makeRefiner()
        let out = try await r.refine("cru", style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(out, "refinado")
    }

    func test_healthCheckCache_avoidsDoubleCall() async throws {
        nonisolated(unsafe) var tagsCalls = 0
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                tagsCalls += 1
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data("{}".utf8))
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"message":{"content":"ok"}}"#.utf8))
        }
        let (r, _) = makeRefiner()
        _ = try await r.refine("a", style: BuiltInStyles.conversaInformal)
        _ = try await r.refine("b", style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(tagsCalls, 1, "cache 30s deveria ter evitado segunda chamada")
    }

    func test_modelNotFound404_throwsModelNotFound() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data("{}".utf8))
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"error":"model \"qwen\" not found"}"#.utf8))
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            if case .modelNotFound = e { /* ok */ } else { XCTFail("expected .modelNotFound, got \(e)") }
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_serverError500_throwsServerError() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data("{}".utf8))
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                    Data())
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .serverError(500))
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_timeout_throwsTimedOut() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data("{}".utf8))
            }
            throw URLError(.timedOut)
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .timedOut)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_malformed_throwsMalformed() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data("{}".utf8))
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("not json".utf8))
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
