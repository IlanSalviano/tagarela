import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class CustomStyleTests: XCTestCase {
    func test_init_setsDefaults() {
        let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        XCTAssertEqual(s.name, "x")
        XCTAssertEqual(s.systemPrompt, "y")
        XCTAssertTrue(s.appendCodeSwitching)
        XCTAssertEqual(s.createdAt.timeIntervalSinceNow, 0, accuracy: 1.0)
    }

    func test_asStyle_appendsCodeSwitchingWhenFlagOn() {
        let s = CustomStyle(name: "x", systemPrompt: "base", appendCodeSwitching: true)
        XCTAssertTrue(s.asStyle().systemPrompt.contains("code-switching") ||
                       s.asStyle().systemPrompt.contains("termos técnicos"))
    }

    func test_asStyle_withoutCodeSwitching_returnsRawPrompt() {
        let s = CustomStyle(name: "x", systemPrompt: "base", appendCodeSwitching: false)
        XCTAssertEqual(s.asStyle().systemPrompt, "base")
    }

    func test_asStyle_isBuiltInIsFalse() {
        let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: false)
        XCTAssertFalse(s.asStyle().isBuiltIn)
    }
}
