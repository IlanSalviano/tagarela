import XCTest
@testable import Tagarela

final class WhisperModelCatalogTests: XCTestCase {

    func test_all_contains_three_models() {
        XCTAssertEqual(WhisperModelCatalog.all.count, 3)
    }

    func test_all_includes_largeV3Turbo_as_recommended_default() {
        let turbo = WhisperModelCatalog.all.first { $0.name == "large-v3_turbo" }
        XCTAssertNotNil(turbo)
        XCTAssertTrue(turbo?.recommended == true)
    }

    func test_all_includes_largeV3() {
        XCTAssertTrue(WhisperModelCatalog.all.contains { $0.name == "large-v3" })
    }

    func test_all_includes_medium() {
        XCTAssertTrue(WhisperModelCatalog.all.contains { $0.name == "medium" })
    }

    func test_all_does_not_include_small_or_distil() {
        let names = WhisperModelCatalog.all.map(\.name)
        XCTAssertFalse(names.contains("small"))
        XCTAssertFalse(names.contains("distil-large-v3"))
    }

    func test_info_lookup_by_name_returns_match() {
        let info = WhisperModelCatalog.info(for: "large-v3_turbo")
        XCTAssertEqual(info?.name, "large-v3_turbo")
        XCTAssertEqual(info?.displaySize, "~1.6 GB")
    }

    func test_info_lookup_unknown_returns_nil() {
        XCTAssertNil(WhisperModelCatalog.info(for: "tiny"))
    }
}
