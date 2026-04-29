import XCTest
@testable import Tagarela

final class IndicatorVariantTests: XCTestCase {
    func test_codableRoundTrip_perCase() throws {
        for v in IndicatorVariant.allCases {
            let data = try JSONEncoder().encode(v)
            let decoded = try JSONDecoder().decode(IndicatorVariant.self, from: data)
            XCTAssertEqual(decoded, v)
        }
    }

    func test_isDarkOnly_onlyHUD() {
        XCTAssertFalse(IndicatorVariant.pill.isDarkOnly)
        XCTAssertFalse(IndicatorVariant.orb.isDarkOnly)
        XCTAssertFalse(IndicatorVariant.vertical.isDarkOnly)
        XCTAssertTrue(IndicatorVariant.hud.isDarkOnly)
    }

    func test_allCases_count4() {
        XCTAssertEqual(Set(IndicatorVariant.allCases),
                       Set([.pill, .orb, .vertical, .hud]))
    }
}
