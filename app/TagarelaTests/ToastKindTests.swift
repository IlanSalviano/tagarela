import XCTest
@testable import Tagarela

final class ToastKindTests: XCTestCase {
    func test_displayMessage_refinerNetworkOffline() {
        let kind = ToastKind.refinerFellBack(reason: .networkOffline)
        XCTAssertTrue(kind.displayMessage.lowercased().contains("rede"))
        XCTAssertTrue(kind.displayMessage.lowercased().contains("cru"))
    }

    func test_displayMessage_refinerServerErrorIncludesCode() {
        let kind = ToastKind.refinerFellBack(reason: .serverError(503))
        XCTAssertTrue(kind.displayMessage.contains("503"))
    }

    func test_displayMessage_refinerModelNotFoundIncludesName() {
        let kind = ToastKind.refinerFellBack(reason: .modelNotFound("gemma4:e4b"))
        XCTAssertTrue(kind.displayMessage.contains("gemma4:e4b"))
    }

    func test_displayMessage_permissionMicrophone() {
        let kind = ToastKind.permissionDenied(kind: .microphone)
        XCTAssertTrue(kind.displayMessage.lowercased().contains("microfone"))
    }

    func test_iconSystemName_perCase() {
        XCTAssertEqual(ToastKind.refinerFellBack(reason: .timedOut).iconSystemName,
                       "exclamationmark.triangle")
        XCTAssertEqual(ToastKind.injectionFailed.iconSystemName,
                       "doc.on.clipboard")
        XCTAssertEqual(ToastKind.historySaveFailed.iconSystemName,
                       "externaldrive.badge.xmark")
        XCTAssertEqual(ToastKind.permissionDenied(kind: .accessibility).iconSystemName,
                       "lock.shield")
    }
}
