import XCTest
@testable import Tagarela

final class RefinerErrorMapperTests: XCTestCase {
    func test_urlError_notConnected_mapsToNetworkOffline() {
        let e = URLError(.notConnectedToInternet)
        XCTAssertEqual(RefinerErrorMapper.from(e), .networkOffline)
    }

    func test_urlError_timedOut_mapsToTimedOut() {
        let e = URLError(.timedOut)
        XCTAssertEqual(RefinerErrorMapper.from(e), .timedOut)
    }

    func test_http401_mapsToUnauthorized() {
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 401, body: Data()),
            .unauthorized)
    }

    func test_http429_mapsToRateLimited() {
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 429, body: Data()),
            .rateLimited)
    }

    func test_http500_mapsToServerError() {
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 503, body: Data()),
            .serverError(503))
    }

    func test_http400_withContextLength_mapsToContextExceeded() {
        let body = Data(#"{"error":"context_length_exceeded"}"#.utf8)
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 400, body: body),
            .contextExceeded)
    }

    func test_http404_withModelMessage_mapsToModelNotFound() {
        let body = Data(#"{"error":"model \"qwen3.5\" not found"}"#.utf8)
        if case let .modelNotFound(name) = RefinerErrorMapper.from(httpStatus: 404, body: body) {
            XCTAssertEqual(name, "qwen3.5")
        } else {
            XCTFail("expected .modelNotFound")
        }
    }

    func test_http404_withUnquotedModelMessage_returnsQuestionMark() {
        let body = Data(#"{"error":"model qwen3.5 not found"}"#.utf8)
        if case let .modelNotFound(name) = RefinerErrorMapper.from(httpStatus: 404, body: body) {
            XCTAssertEqual(name, "?")
        } else {
            XCTFail("expected .modelNotFound")
        }
    }

    func test_urlError_cancelled_mapsToCancelled() {
        let e = URLError(.cancelled)
        XCTAssertEqual(RefinerErrorMapper.from(e), .cancelled)
    }
}
