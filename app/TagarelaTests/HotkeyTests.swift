import XCTest
@testable import Tagarela

final class HotkeyTests: XCTestCase {
    func test_default_isRightOption() {
        XCTAssertEqual(Hotkey.default, .rightOption)
    }

    func test_codable_roundTrip() throws {
        let h = Hotkey.rightOption
        let data = try JSONEncoder().encode(h)
        let decoded = try JSONDecoder().decode(Hotkey.self, from: data)
        XCTAssertEqual(decoded, h)
    }

    func test_virtualKeyCode_rightOption() {
        XCTAssertEqual(Hotkey.rightOption.virtualKeyCode, 0x3D)
    }

    func test_displayLabel_rightOption() {
        XCTAssertEqual(Hotkey.rightOption.displayLabel, "right ⌥")
    }
}
