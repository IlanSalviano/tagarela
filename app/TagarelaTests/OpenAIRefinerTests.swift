import XCTest
@testable import Tagarela

final class OpenAIRefinerTests: XCTestCase {
    private var keychain: FakeKeychainService!

    override func setUp() async throws {
        keychain = FakeKeychainService(initial: "sk-fake")
        MockURLProtocol.responder = nil
    }

    override func tearDown() async throws {
        MockURLProtocol.responder = nil
    }

    private func makeRefiner(timeout: TimeInterval = 30) -> OpenAIRefiner {
        OpenAIRefiner(session: MockURLProtocol.session(),
                      keychain: keychain,
                      model: "gpt-5.4-mini",
                      timeoutSec: timeout)
    }

    private func httpResp(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func successBody(_ content: String) -> Data {
        let json: [String: Any] = ["choices": [["message": ["content": content]]]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    func test_success_returnsRefinedText() async throws {
        MockURLProtocol.responder = { _ in (self.httpResp(200), self.successBody("texto refinado")) }
        let r = makeRefiner()
        let out = try await r.refine("texto cru", style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(out, "texto refinado")
    }

    func test_unauthorized401_throwsUnauthorized() async {
        MockURLProtocol.responder = { _ in (self.httpResp(401), Data()) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .unauthorized)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_serverError500_throwsServerError() async {
        MockURLProtocol.responder = { _ in (self.httpResp(503), Data()) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .serverError(503))
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_timeout_throwsTimedOut() async {
        MockURLProtocol.responder = { _ in throw URLError(.timedOut) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .timedOut)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_rateLimited429_throwsRateLimited() async {
        MockURLProtocol.responder = { _ in (self.httpResp(429), Data()) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .rateLimited)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_malformedJSON_throwsMalformed() async {
        MockURLProtocol.responder = { _ in (self.httpResp(200), Data("not json".utf8)) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_missingChoicesField_throwsMalformed() async {
        MockURLProtocol.responder = { _ in (self.httpResp(200), Data(#"{"foo":"bar"}"#.utf8)) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_contextExceeded_truncatesAndRetries_succeedsOnSecondTry() async throws {
        var attempts = 0
        MockURLProtocol.responder = { _ in
            attempts += 1
            if attempts == 1 {
                return (self.httpResp(400), Data(#"{"error":"context_length_exceeded"}"#.utf8))
            }
            return (self.httpResp(200), self.successBody("ok"))
        }
        let r = makeRefiner()
        let out = try await r.refine(String(repeating: "a", count: 100), style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(out, "ok")
        XCTAssertEqual(attempts, 2)
    }

    func test_contextExceededTwice_throwsContextExceeded() async {
        MockURLProtocol.responder = { _ in
            (self.httpResp(400), Data(#"{"error":"context_length_exceeded"}"#.utf8))
        }
        let r = makeRefiner()
        do {
            _ = try await r.refine(String(repeating: "a", count: 100), style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .contextExceeded)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_emptyApiKey_throwsUnauthorized_withoutHTTP() async {
        keychain = FakeKeychainService(initial: nil)
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .unauthorized)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_keychainThrows_mapsToUnauthorized_withoutHTTP() async {
        let throwingKeychain = ThrowingFakeKeychainService(error: .osStatus(-25300))
        let r = OpenAIRefiner(session: MockURLProtocol.session(),
                              keychain: throwingKeychain,
                              model: "gpt-5.4-mini",
                              timeoutSec: 30)
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .unauthorized)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_emptyStringApiKey_throwsUnauthorized_withoutHTTP() async {
        keychain = FakeKeychainService(initial: "")
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .unauthorized)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
