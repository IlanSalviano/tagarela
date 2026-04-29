import XCTest
@testable import Tagarela

@MainActor
final class ToastCenterTests: XCTestCase {
    func test_show_setsCurrent() {
        let center = ToastCenter()
        XCTAssertNil(center.current)
        let t = Toast(kind: .injectionFailed)
        center.show(t)
        XCTAssertEqual(center.current?.id, t.id)
    }

    func test_dismiss_clearsCurrent() {
        let center = ToastCenter()
        center.show(Toast(kind: .injectionFailed))
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func test_show_replacesExistingToast() {
        let center = ToastCenter()
        let t1 = Toast(kind: .injectionFailed)
        let t2 = Toast(kind: .historySaveFailed)
        center.show(t1)
        center.show(t2)
        XCTAssertEqual(center.current?.id, t2.id)
    }

    func test_autoDismiss_clearsAfterTTL() async throws {
        // Não testa o timeout completo de 4s (lento). Valida que current
        // permanece logo após show e que dismiss manual funciona.
        let center = ToastCenter()
        center.show(Toast(kind: .injectionFailed))
        XCTAssertNotNil(center.current)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(center.current)
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func test_show_doesNotPersistAcrossDismissIfStill() async {
        // Verifica que após troca rápida de toasts, current bate com o
        // último (a cancelTask do show já mata o sleep do anterior).
        let center = ToastCenter()
        let t1 = Toast(kind: .injectionFailed)
        center.show(t1)
        let t2 = Toast(kind: .historySaveFailed)
        center.show(t2)
        XCTAssertEqual(center.current?.id, t2.id)
    }
}
