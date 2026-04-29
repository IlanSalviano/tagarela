import XCTest
@testable import Tagarela

final class RefinerFallbackReasonTests: XCTestCase {
    func test_initFromRefinerError_networkOffline() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .networkOffline), .networkOffline)
    }

    func test_initFromRefinerError_unauthorized() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .unauthorized), .unauthorized)
    }

    func test_initFromRefinerError_timedOut() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .timedOut), .timedOut)
    }

    func test_initFromRefinerError_serverErrorPreservesCode() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .serverError(503)),
                       .serverError(503))
    }

    func test_initFromRefinerError_modelNotFoundPreservesName() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .modelNotFound("xyz:fake")),
                       .modelNotFound("xyz:fake"))
    }

    func test_initFromRefinerError_cancelledReturnsNil() {
        XCTAssertNil(RefinerFallbackReason(refinerError: .cancelled))
    }
}
