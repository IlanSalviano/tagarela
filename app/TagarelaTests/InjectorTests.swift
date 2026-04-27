import XCTest
@testable import Tagarela

final class InjectorTests: XCTestCase {
    func test_injectionError_equatable() {
        XCTAssertEqual(InjectionError.accessibilityDenied,
                       InjectionError.accessibilityDenied)
        XCTAssertNotEqual(InjectionError.accessibilityDenied,
                          InjectionError.pasteboardWriteFailed)
    }
}
